# frozen_string_literal: true

module Reimbursement
  module ReportService
    class BulkCreate
      REQUIRED_HEADERS = %w[email report_name].freeze
      OPTIONAL_HEADERS = %w[maximum_amount_cents invite_message].freeze
      ALL_HEADERS = REQUIRED_HEADERS + OPTIONAL_HEADERS
      MAX_ERRORS_TO_DISPLAY = 10

      Result = Struct.new(:success?, :reports, :errors, keyword_init: true)

      def initialize(event:, csv_file:, sent_by:, reviewer_id: nil)
        @event = event
        @csv_file = csv_file
        @sent_by = sent_by
        @reviewer_id = reviewer_id
      end

      def run
        rows, header_mapping = Shared::CsvUpload.new(csv_file: @csv_file).run
        attributes = rows.map do |row|
          ALL_HEADERS.to_h do |header|
            original_header = header_mapping[header]
            [header, original_header ? row[original_header]&.strip.presence : nil]
          end
        end
        validate_rows!(attributes, header_mapping)
        reports = create_reports_atomically(attributes)

        Result.new(success?: true, reports:, errors: [])
      rescue Shared::CsvUpload::ValidationError => e
        Result.new(success?: false, reports: [], errors: e.errors)
      end

      private

      def validate_rows!(attributes, header_mapping)
        errors = []
        missing_headers = REQUIRED_HEADERS - header_mapping.keys
        errors << "Missing required headers: #{missing_headers.join(", ")}" if missing_headers.any?
        errors << "CSV file has no data rows" if attributes.empty?

        report = Report.new(event: @event)
        if report.assigned_reviewer_required?
          @reviewer = report.eligible_reviewers.find_by_public_id(@reviewer_id)
          errors << "Please select an eligible reviewer for these reports" unless @reviewer
        end

        attributes.each.with_index(2) do |fields, line_number|
          email = fields["email"]
          if email.blank?
            errors << "Row #{line_number}: email is required"
          elsif ValidatesEmailFormatOf.validate_email_format(email).present?
            errors << "Row #{line_number}: '#{email}' is not a valid email address"
          end
          errors << "Row #{line_number}: report_name is required" if fields["report_name"].blank?

          amount = fields["maximum_amount_cents"]
          if amount.present? && (!amount.match?(/\A\d+\z/) || amount.to_i <= 0 || amount.to_i > 2147483647)
            errors << "Row #{line_number}: maximum_amount_cents must be a positive whole number no greater than 2147483647"
          end

        end

        if errors.any?
          displayed_errors = errors.first(MAX_ERRORS_TO_DISPLAY)
          displayed_errors << "...and #{errors.size - MAX_ERRORS_TO_DISPLAY} more errors" if errors.size > MAX_ERRORS_TO_DISPLAY
          raise Shared::CsvUpload::ValidationError.new(displayed_errors)
        end
      end

      def create_reports_atomically(attributes)
        ActiveRecord::Base.transaction do
          attributes.map.with_index(2) do |fields, line_number|
            user = User.create_with(creation_method: :reimbursement_report).find_or_create_by!(email: fields["email"])
            @event.reimbursement_reports.create!(
              user:,
              inviter: @sent_by,
              report_name: fields["report_name"],
              maximum_amount_cents: fields["maximum_amount_cents"]&.to_i,
              invite_message: fields["invite_message"],
              currency: user.default_payout_method&.currency || "USD",
              reviewer: @reviewer
            )
          rescue ActiveRecord::RecordInvalid => e
            raise Shared::CsvUpload::ValidationError.new(["Row #{line_number}: #{e.record.errors.full_messages.to_sentence}"])
          end
        end
      end

    end
  end
end
