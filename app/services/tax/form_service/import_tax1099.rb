# frozen_string_literal: true

module Tax
  module FormService
    # Imports Tax1099's W-9s and W-8s as manual tax forms and claims each for its filer's
    # legal entities. A TIN is only ever fingerprinted: never stored, logged, or printed.
    class ImportTax1099
      # Each field, and the export headers it may appear under.
      HEADERS = {
        email: ["email", "email address", "recipient email", "payee email"],
        name: ["business name", "legal name", "name", "recipient name", "payee name"],
        form_type: ["form type", "form"],
        tin: ["tin", "ein/ssn", "ssn/ein", "tax id", "recipient tin"],
        tin_type: ["tin type", "tax id type"],
        classification: ["federal tax classification", "tax classification"],
        signed_on: ["signed date", "date signed", "received date", "date received", "completed date"],
        tin_match: ["tin match", "tin match status", "tin matching status"]
      }.freeze

      INDIVIDUAL_TINS = %w[SSN ITIN ATIN].freeze

      def initialize(csv:, commit: false, form_type: nil)
        @csv = csv
        @commit = commit
        @form_type = form_type
        @notes = []
      end

      def run
        rows = CSV.parse(@csv.scrub, headers: true)
        headers = rows.headers.compact.index_by { |header| normalize(header) }
        @columns = HEADERS.transform_values { |names| names.filter_map { |name| headers[normalize(name)] } }

        # Never echo the headers found: an export without a header row starts with a TIN.
        missing = %i[email tin].select { |field| @columns[field].empty? }
        missing << :form_type if @columns[:form_type].empty? && @form_type.nil?
        raise ArgumentError, "the export needs #{missing.map { |field| "a #{field} column (#{HEADERS[field].join(", ")})" }.to_sentence}" if missing.any?

        # A filing exported more than once keeps its latest signature.
        records = rows.each.with_index(2).filter_map { |row, line| record_for(row, line) }
                      .group_by { |record| record.values_at(:import_email, :tin_hash, :form_type) }
                      .map { |_filing, copies| copies.max_by { |record| record[:completed_at] } }
        forms = Form.where(import_email: records.pluck(:import_email))
        counts = nil

        ActiveRecord::Base.transaction do
          import(records)
          counts = [forms.where.not(legal_entity_id: nil).count, forms.unclaimed.count]
          raise ActiveRecord::Rollback unless @commit
        end

        LegalEntity.where(id: forms.select(:legal_entity_id)).find_each { |legal_entity| safely { legal_entity.refresh_pending_contractors_payments! } } if @commit

        [
          @commit ? "Imported." : "Dry run, so nothing was saved. Re-run with COMMIT=1 to import.",
          "#{rows.size} rows, #{records.size} forms: #{counts.first} claimed by legal entities, #{counts.last} left unclaimed.",
          *@notes
        ]
      end

      private

      def import(records)
        forms = records.map do |record|
          Form.not_discarded.find_or_create_by!(record.slice(:import_email, :tin_hash, :form_type)) do |form|
            form.assign_attributes(record.merge(aasm_state: :unclaimed, external_service: :manual))
          end
        end

        # Anyone already on file with the same TIN is the same filer, whoever owns them.
        forms.select(&:tin_hash).each do |form|
          LegalEntity.not_archived.where(tin_hash: form.tin_hash).find_each do |legal_entity|
            form.claim!(legal_entity) || note("#{form.import_email}'s #{form.form_type} doesn't fit #{legal_entity.public_id}, which has the same TIN")
          end
        end

        forms.map(&:import_email).uniq.each do |email|
          user = User.find_by(email:)
          Form.claim_for!(user).each { |form| note("#{email}'s #{form.form_type} needs someone to pick its legal entity") } if user

          # Payees imported from the old transfer system were paid under these forms.
          LegalEntity.managed.not_archived.joins(:payees).where(payees: { email: }).where.not(payees: { imported_at: nil }).distinct.each do |legal_entity|
            candidates = Form.imported_for(email).select { |form| form.claimable_by?(legal_entity) }
            next candidates.sole.claim!(legal_entity) if candidates.one?

            note("#{email} has #{candidates.size} forms that fit #{legal_entity.public_id}, so it got none")
          end
        end
      end

      def record_for(row, line)
        value = ->(field) { @columns[field].map { |header| row[header].to_s.strip }.find(&:present?) }

        form_type = (value[:form_type] || @form_type).to_s.upcase.delete("^A-Z0-9").delete_prefix("FORM")
        return note("Row #{line} has an unknown form type, so it was skipped") unless Form.form_types.key?(form_type)
        return note("Row #{line} has no email, so it was skipped") if value[:email].nil?

        tin_type = value[:tin_type]&.upcase&.delete("^A-Z") || tin_type_from_format(value[:tin])
        entity_type = case form_type
                      when "W8BEN" then :person
                      when "W9", "W8ECI" then entity_type_for(tin_type, value[:classification])
                      else :business
                      end
        return note("Row #{line} has an unknown TIN type, so it was skipped") if entity_type.nil?

        # Only a US TIN is fingerprinted: a foreign one needs a residence country the
        # export can't reliably give, and TaxBandits leaves those unhashed too.
        tin_hash = if tin_type.in?([*INDIVIDUAL_TINS, "EIN"])
                     IdentificationNumber::Hasher.hash_tin(value[:tin], tin_type: IdentificationNumber::Hasher.tin_type_for(entity_type:), country: "US")
                   end
        return note("Row #{line} is a W-9 with no TIN, so it was skipped") if form_type == "W9" && tin_hash.nil?

        {
          import_email: value[:email].downcase,
          import_name: value[:name],
          form_type:,
          entity_type:,
          tin_type: (IdentificationNumber::Hasher.tin_type_for(entity_type:) if tin_hash),
          tin_hash:,
          taxbandits_tin_matching_status: tin_match(value[:tin_match]),
          completed_at: signed_on(value[:signed_on]) || Time.current
        }
      end

      def entity_type_for(tin_type, classification)
        if tin_type.in?(INDIVIDUAL_TINS)
          :person
        elsif tin_type == "EIN"
          classification.to_s.downcase.include?("corporation") ? :corporation : :business
        end
      end

      def tin_type_from_format(tin)
        case tin
        when /\A\d{3}-\d{2}-\d{4}\z/ then "SSN"
        when /\A\d{2}-\d{7}\z/ then "EIN"
        end
      end

      def tin_match(status)
        case status.to_s.downcase.delete("^a-z")
        when "success", "match", "matched", "valid", "verified" then :success
        when "failed", "fail", "mismatch", "mismatched", "notmatched", "nomatch", "invalid" then :failed
        end
      end

      def signed_on(value)
        return if value.nil?

        date = Date.strptime(value[/\S+/], value.include?("/") ? "%m/%d/%Y" : "%Y-%m-%d")
        (date.year < 100 ? date.next_year(2000) : date).in_time_zone
      rescue Date::Error
        nil
      end

      def normalize(header)
        header.to_s.downcase.delete("^a-z0-9")
      end

      def note(message)
        @notes << "#{message}."
        false
      end

    end
  end
end
