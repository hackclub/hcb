# frozen_string_literal: true

require "csv"

module CardGrantService
  class BulkCreate
    # Contract:
    # - Returns Result for CSV/validation errors.
    # - Raises DisbursementService::Create::UserError for disbursement failures
    #   (e.g., insufficient funds).
    # - Propagates any other unexpected errors.

    ValidationError = Shared::CsvUpload::ValidationError

    REQUIRED_HEADERS = %w[email amount_cents].freeze
    OPTIONAL_HEADERS = %w[purpose instructions one_time_use pre_authorization_required invite_message merchant_lock category_lock keyword_lock banned_merchants banned_categories].freeze
    ALL_HEADERS = REQUIRED_HEADERS + OPTIONAL_HEADERS
    MAX_ERRORS_TO_DISPLAY = 10
    MAX_FILE_SIZE_BYTES = Shared::CsvUpload::MAX_FILE_SIZE_BYTES

    Result = Struct.new(:success?, :card_grants, :errors, keyword_init: true)

    def initialize(event:, csv_file:, sent_by:)
      @event = event
      @csv_file = csv_file
      @sent_by = sent_by
    end

    def run
      rows, header_mapping = Shared::CsvUpload.new(csv_file: @csv_file).run
      validate_rows!(rows, header_mapping)
      card_grants = create_grants_atomically(rows, header_mapping)

      Result.new(success?: true, card_grants:, errors: [])
    rescue ValidationError => e
      Result.new(success?: false, card_grants: [], errors: e.errors)
    end

    private

    def validate_rows!(rows, header_mapping)
      errors = []

      missing_headers = REQUIRED_HEADERS - header_mapping.keys
      if missing_headers.any?
        errors << "Missing required headers: #{missing_headers.join(", ")}"
      end

      if rows.empty?
        errors << "CSV file has no data rows"
      end

      rows.each.with_index(2) do |row, line_number|
        row_errors = validate_row(row, header_mapping, line_number)
        errors.concat(row_errors)
      end

      if errors.any?
        total_errors = errors.count
        if total_errors > MAX_ERRORS_TO_DISPLAY
          errors = errors.first(MAX_ERRORS_TO_DISPLAY)
          errors << "...and #{total_errors - MAX_ERRORS_TO_DISPLAY} more errors"
        end
        raise ValidationError.new(errors)
      end
    end

    def validate_row(row, header_mapping, line_number)
      errors = []

      email = get_field(row, header_mapping, "email")&.strip
      if email.blank?
        errors << "Row #{line_number}: email is required"
      elsif ValidatesEmailFormatOf.validate_email_format(email).present?
        errors << "Row #{line_number}: '#{email}' is not a valid email address"
      end

      amount_cents = parse_amount(get_field(row, header_mapping, "amount_cents"))
      if amount_cents.nil?
        errors << "Row #{line_number}: amount_cents is required"
      elsif amount_cents == :negative
        errors << "Row #{line_number}: amount_cents cannot be negative"
      elsif amount_cents == :invalid
        errors << "Row #{line_number}: amount_cents must be an integer greater than 0 (in cents)"
      elsif amount_cents <= 0
        errors << "Row #{line_number}: amount_cents must be an integer greater than 0 (in cents)"
      end

      purpose = get_field(row, header_mapping, "purpose")&.strip
      if purpose.present? && purpose.length > CardGrant::MAXIMUM_PURPOSE_LENGTH
        errors << "Row #{line_number}: purpose exceeds maximum length of #{CardGrant::MAXIMUM_PURPOSE_LENGTH} characters"
      end

      errors
    end

    def get_field(row, header_mapping, field_name)
      original_header = header_mapping[field_name]
      return nil unless original_header

      row[original_header]
    end

    def parse_amount(value)
      return nil if value.blank?

      cleaned = value.to_s.strip

      # Only accept positive integers (cents)
      return :negative if cleaned.start_with?("-")
      return :invalid unless cleaned.match?(/\A\d+\z/)

      cleaned.to_i
    end

    def create_grants_atomically(rows, header_mapping)
      card_grants = []

      ActiveRecord::Base.transaction do
        rows.each do |row|
          card_grant = build_card_grant(row, header_mapping)
          card_grant.save!
          card_grants << card_grant
        end
      end

      card_grants
    end

    def build_card_grant(row, header_mapping)
      @event.card_grants.build(
        email: get_field(row, header_mapping, "email")&.strip,
        amount_cents: parse_amount(get_field(row, header_mapping, "amount_cents")),
        purpose: get_field(row, header_mapping, "purpose")&.strip.presence,
        instructions: get_field(row, header_mapping, "instructions")&.strip.presence,
        one_time_use: parse_boolean(get_field(row, header_mapping, "one_time_use")),
        pre_authorization_required: parse_boolean(get_field(row, header_mapping, "pre_authorization_required")),
        invite_message: get_field(row, header_mapping, "invite_message")&.strip.presence,
        merchant_lock: parse_comma_separated(get_field(row, header_mapping, "merchant_lock")),
        category_lock: parse_comma_separated(get_field(row, header_mapping, "category_lock")),
        keyword_lock: get_field(row, header_mapping, "keyword_lock")&.strip.presence,
        banned_merchants: parse_comma_separated(get_field(row, header_mapping, "banned_merchants")),
        banned_categories: parse_comma_separated(get_field(row, header_mapping, "banned_categories")),
        sent_by: @sent_by,
      )
    end

    def parse_boolean(value)
      return false if value.blank?

      %w[true 1 yes].include?(value.to_s.strip.downcase)
    end

    def parse_comma_separated(value)
      return nil if value.blank?

      value.to_s.split(",").map(&:strip).reject(&:blank?)
    end

  end
end
