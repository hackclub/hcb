# frozen_string_literal: true

require "csv"

module Tax1099Service
  # One-time importer for the Tax1099 "W8/W9 Report" export, run when HCB moved
  # its tax paperwork to TaxBandits. Every row is a certificate a payee has
  # already signed, so each lands as a completed manual Tax::Form and TaxBandits
  # stays the source of truth for everything filed since.
  #
  # The export carries raw TINs. Nothing here logs, stores or reports one: a TIN
  # is fingerprinted and dropped, and every message this returns is keyed by row
  # number and email. Delete the file once the run is done.
  class Import
    class HeaderError < StandardError; end

    Result = Struct.new(:imported, :skipped, :review, :errors, keyword_init: true)

    # Tax1099 has renamed these columns between exports, so each field accepts
    # any spelling we have seen rather than one exact header.
    COLUMNS = {
      email: ["email", "email address", "recipient email"],
      tin: ["tin", "tax id", "taxpayer id", "taxpayer identification number", "ssn ein"],
      tin_type: ["tin type", "tax id type", "id type"],
      form_type: ["form type", "form", "w8 w9", "certificate type"],
      completed_at: ["date submitted", "submitted date", "signed date", "date signed", "w9 received date"],
      name: ["name", "recipient name", "payee name", "legal name"],
      business_name: ["business name", "company name", "dba"],
      address_line1: ["address", "address 1", "address line 1", "street address"],
      address_line2: ["address 2", "address line 2"],
      city: ["city"],
      state: ["state", "state province", "province"],
      postal_code: ["zip", "zip code", "postal code"],
      country: ["country", "country of residence", "residence country"],
    }.freeze

    REQUIRED_COLUMNS = %i[email tin form_type completed_at].freeze

    FORM_TYPES = {
      "w 9"      => "W9",
      "w9"       => "W9",
      "w 8ben"   => "W8BEN",
      "w8ben"    => "W8BEN",
      "w 8ben e" => "W8BENE",
      "w8ben e"  => "W8BENE",
      "w8bene"   => "W8BENE",
      "w 8eci"   => "W8ECI",
      "w8eci"    => "W8ECI",
      "w 8imy"   => "W8IMY",
      "w8imy"    => "W8IMY",
      "w 8exp"   => "W8EXP",
      "w8exp"    => "W8EXP",
    }.freeze

    BUSINESS_FORM_TYPES = %w[W8BENE W8IMY W8EXP].freeze
    INDIVIDUAL_TIN_TYPES = %w[ssn itin atin].freeze
    ENTITY_TIN_TYPES = %w[ein].freeze

    # Tax1099 exports US-ordered dates, which Time.zone.parse reads day-first.
    # Four-digit years come first so a two-digit pattern can't half-match one.
    DATE_FORMATS = ["%m/%d/%Y", "%Y-%m-%d", "%m/%d/%y"].freeze
    MIN_FILING_YEAR = 1990

    def initialize(csv:, dry_run: false)
      @csv = csv
      @dry_run = dry_run
      @result = Result.new(imported: 0, skipped: 0, review: [], errors: [])
    end

    def run
      rows = parse

      ApplicationRecord.transaction do
        rows.each.with_index(2) do |row, line|
          # A savepoint per row: one row that can't be filed leaves the rest of
          # the import, and the run's place in the file, intact.
          ApplicationRecord.transaction(requires_new: true) { import_row(row, line) }
        rescue => e
          # The row's TIN is in scope here, so an arbitrary error's message could
          # carry it. Only a validation failure, which never sees the TIN (it is
          # fingerprinted, never assigned), is quoted.
          @result.errors << "Row #{line}: #{e.is_a?(ActiveRecord::RecordInvalid) ? e.message : e.class}"
        end

        raise ActiveRecord::Rollback if @dry_run
      end

      @result
    end

    private

    def parse
      # Excel writes a byte order mark ahead of the first header.
      content = @csv.to_s.delete_prefix("\uFEFF")
      rows = CSV.parse(content, headers: true, skip_blanks: true)

      @headers = COLUMNS.transform_values do |candidates|
        rows.headers.compact.find { |header| candidates.include?(normalize(header)) }
      end

      missing = REQUIRED_COLUMNS.select { |column| @headers[column].nil? }
      raise HeaderError, "CSV has no column for: #{missing.join(", ")}" if missing.any?

      rows
    end

    def import_row(row, line)
      email = field(row, :email)&.downcase
      form_type = FORM_TYPES[normalize(field(row, :form_type))]
      tin_type = field(row, :tin_type)&.downcase
      completed_at = parse_time(field(row, :completed_at))

      return invalid(line, email, "email is missing or invalid") if email.blank? || ValidatesEmailFormatOf.validate_email_format(email).present?
      return invalid(line, email, "form type is not one we file") if form_type.nil?
      return invalid(line, email, "submission date is missing or unreadable") if completed_at.nil?

      entity_type = entity_type_for(form_type, tin_type)
      return review(line, email, "a W-9 that doesn't say whether its TIN is an SSN or an EIN could be either a person or a business") if entity_type.nil?

      tin_type_key = Tax::IdentificationNumber::Hasher.tin_type_for(entity_type:, foreign: foreign?(form_type, tin_type))
      country = tin_type_key == Tax::IdentificationNumber::Hasher::FOREIGN ? field(row, :country) : "US"
      tin = field(row, :tin)
      # A foreign TIN we can't place in an issuing country is left un-fingerprinted
      # rather than bucketed by guess, which would risk merging two taxpayers.
      tin_hash = Tax::IdentificationNumber::Hasher.hash_tin(tin, tin_type: tin_type_key, country:) if tin.present? && country.present?

      legal_entity = LegalEntity.not_archived.order(:id).find_by(tin_hash:) if tin_hash
      legal_entity ||= legal_entity_for(row, line, email, entity_type)
      return if legal_entity.nil?

      file_form(row, line, email, legal_entity, form_type:, entity_type:, tin_type: tin_type_key, tin_hash:, completed_at:, country:)
    end

    # No legal entity carries this TIN yet, so the form belongs to whoever owns
    # the email on it, on the personal or business entity the form describes.
    def legal_entity_for(row, line, email, entity_type)
      user = User.find_by(email:) || User.create!(email:)

      if entity_type == :person
        user.personal_legal_entity || user.send(:create_legal_entity)
      elsif user.legal_entities.not_archived.where(entity_type: [:business, :corporation]).exists?
        # Whether this form belongs to a business they already have, or to one
        # more we don't know about, is a judgement call rather than a guess.
        review(line, email, "user already has a business legal entity")
      else
        LegalEntity.create!(entity_type:, name: field(row, :business_name) || field(row, :name)).tap do |legal_entity|
          legal_entity.legal_entity_users.create!(user:)
        end
      end
    end

    def file_form(row, line, email, legal_entity, form_type:, entity_type:, tin_type:, tin_hash:, completed_at:, country:)
      # Filing a TIN against an entity that reports a different one makes that
      # entity permanently unpayable, so it goes to a human instead.
      return review(line, email, "legal entity is identified by a different TIN") if legal_entity.tin_hash.present? && legal_entity.tin_hash != tin_hash

      # Imported forms are historical: whatever date the export claims, one must
      # never outrank a form the payee has since completed through TaxBandits.
      # Read off TaxBandits forms alone, so replaying the export clamps to the
      # same instant and dedupes against what the first run wrote.
      latest = legal_entity.tax_forms.sent_with_taxbandits.completed.maximum(:completed_at)
      completed_at = [completed_at, latest - 1.second].min if latest

      if legal_entity.tax_forms.sent_with_manual.exists?(form_type:, tin_hash:, completed_at:)
        @result.skipped += 1
        return
      end

      legal_entity.tax_forms.create!(
        external_service: :manual,
        aasm_state: :completed,
        form_type:,
        entity_type:,
        tin_type:,
        tin_hash:,
        completed_at:,
        address_line1: field(row, :address_line1),
        address_line2: field(row, :address_line2),
        address_city: field(row, :city),
        address_state: field(row, :state),
        address_postal_code: field(row, :postal_code),
        address_country: field(row, :country) || country
      )

      # Created rather than transitioned, so the work mark_completed would have
      # done has to be done here: a payee blocked only on tax paperwork is now
      # payable, and this is what releases their pending payments.
      legal_entity.refresh_pending_contractors_payments!

      @result.imported += 1
    end

    # An SSN identifies a person and an EIN a business; a W-8BEN is only ever
    # filed by an individual, and the entity W-8s only ever by a business.
    def entity_type_for(form_type, tin_type)
      return :person if form_type == "W8BEN"
      return :business if BUSINESS_FORM_TYPES.include?(form_type)
      return :person if INDIVIDUAL_TIN_TYPES.include?(tin_type)
      return :business if ENTITY_TIN_TYPES.include?(tin_type)

      nil
    end

    # A W-8 filer who gave us no US TIN is identified by their foreign one, which
    # is only unique within the country that issued it.
    def foreign?(form_type, tin_type)
      form_type != "W9" && !INDIVIDUAL_TIN_TYPES.include?(tin_type) && !ENTITY_TIN_TYPES.include?(tin_type)
    end

    def field(row, column)
      header = @headers[column]
      row[header]&.strip.presence if header
    end

    def normalize(value)
      value.to_s.downcase.gsub(/[^a-z0-9]+/, " ").squish
    end

    def parse_time(value)
      return nil if value.blank?

      DATE_FORMATS.each do |format|
        parsed = strptime(value, format)
        return parsed if plausible?(parsed)
      end

      parsed = Time.zone.parse(value) rescue nil
      parsed if plausible?(parsed)
    end

    def strptime(value, format)
      Time.zone.strptime(value, format)
    rescue ArgumentError
      nil
    end

    # A date the export can't have produced, such as a two-digit year read as a
    # four-digit one, is a misread of the cell rather than a filing.
    def plausible?(time)
      time.present? && time.year >= MIN_FILING_YEAR
    end

    def review(line, email, reason)
      @result.review << "Row #{line} (#{email}): #{reason}"
      nil
    end

    def invalid(line, email, reason)
      @result.errors << "Row #{line} (#{email}): #{reason}"
      nil
    end

  end
end
