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

    # Derived from the model so it can't drift from what we're allowed to store.
    # Longest first: "w8bene" has to win before "w8ben" can match its prefix.
    FORM_TYPES = Tax::Form.form_types.keys.sort_by { |type| -type.length }.freeze

    BUSINESS_FORM_TYPES = %w[W8BENE W8IMY W8EXP].freeze

    # Matched as substrings of the normalized cell, so both a code and its spelt
    # out form land in the same bucket. Anything in neither list is a TIN the IRS
    # didn't issue, which is what makes a W-8 filer foreign.
    INDIVIDUAL_TIN_TYPES = ["ssn", "itin", "atin", "social security", "individual taxpayer"].freeze
    ENTITY_TIN_TYPES = ["ein", "employer identification"].freeze

    # Tax1099 exports US-ordered dates, which Time.zone.parse reads day-first.
    # Four-digit years come first so a two-digit pattern can't half-match one.
    DATE_FORMATS = ["%m/%d/%Y", "%Y-%m-%d", "%m/%d/%y"].freeze
    MIN_FILING_YEAR = 1990

    # `columns` maps a field to the exact header carrying it, for an export whose
    # spelling the aliases above don't cover. Tax1099 lets whoever runs the export
    # choose its headers, so there is no one schema to hard-code against.
    def initialize(csv:, dry_run: false, columns: {})
      @csv = csv
      @dry_run = dry_run
      @overrides = columns.symbolize_keys
      @result = Result.new(imported: 0, skipped: 0, review: [], errors: [])
    end

    # Which header each field resolved to, for confirming the mapping before a
    # run. Reads headers only, never a row, so it never touches a TIN.
    def column_mapping
      resolve_columns(CSV.parse_line(content, headers: true)&.headers || [])
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
      rows = CSV.parse(content, headers: true, skip_blanks: true)
      @headers = resolve_columns(rows.headers)

      missing = REQUIRED_COLUMNS.select { |column| @headers[column].nil? }
      if missing.any?
        # Name what the file actually has: the fix is almost always re-exporting
        # with a different header selected, or passing that header in `columns`.
        raise HeaderError, "CSV has no column for #{missing.join(", ")}. " \
                           "Its headers are: #{rows.headers.compact.join(", ")}"
      end

      rows
    end

    # Excel writes a byte order mark ahead of the first header.
    def content
      @content ||= @csv.to_s.delete_prefix("\uFEFF")
    end

    def resolve_columns(headers)
      present = headers.compact
      COLUMNS.to_h do |column, candidates|
        override = @overrides[column].presence
        [column, override || present.find { |header| candidates.include?(normalize(header)) }]
      end
    end

    def import_row(row, line)
      email = field(row, :email)&.downcase
      form_type = form_type_for(field(row, :form_type))
      tin_kind = tin_kind_for(field(row, :tin_type))
      completed_at = parse_time(field(row, :completed_at))

      return invalid(line, email, "email is missing or invalid") if email.blank? || ValidatesEmailFormatOf.validate_email_format(email).present?
      return invalid(line, email, "form type is not one we file") if form_type.nil?
      return invalid(line, email, "submission date is missing or unreadable") if completed_at.nil?

      entity_type = entity_type_for(form_type, tin_kind)
      return review(line, email, "a W-9 that doesn't say whether its TIN is an SSN or an EIN could be either a person or a business") if entity_type.nil?

      tin_type_key = Tax::IdentificationNumber::Hasher.tin_type_for(entity_type:, foreign: foreign?(form_type, tin_kind))
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

    # Matched on the alphanumerics alone, so "W-9", "W9" and "Form W-9 (Rev.
    # 10-2018)" all reach the same form type whichever way the export spells it.
    def form_type_for(value)
      squeezed = value.to_s.downcase.delete("^a-z0-9").delete_prefix("form")

      FORM_TYPES.find { |form_type| squeezed.start_with?(form_type.downcase) }
    end

    def tin_kind_for(value)
      normalized = normalize(value)
      return nil if normalized.blank?
      return :individual if INDIVIDUAL_TIN_TYPES.any? { |token| normalized.include?(token) }
      return :entity if ENTITY_TIN_TYPES.any? { |token| normalized.include?(token) }

      nil
    end

    # An SSN identifies a person and an EIN a business; a W-8BEN is only ever
    # filed by an individual, and the entity W-8s only ever by a business.
    def entity_type_for(form_type, tin_kind)
      return :person if form_type == "W8BEN"
      return :business if BUSINESS_FORM_TYPES.include?(form_type)
      return :person if tin_kind == :individual
      return :business if tin_kind == :entity

      nil
    end

    # A W-8 filer whose TIN the IRS didn't issue is identified by their foreign
    # one, which is only unique within the country that issued it.
    def foreign?(form_type, tin_kind)
      form_type != "W9" && tin_kind.nil?
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
