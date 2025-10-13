# frozen_string_literal: true

module ExportService
  module Reimbursement
    class Csv
      def initialize(event_id:, public_only:)
        raise ArgumentError.new("Organizers only") if public_only

        @event = Event.find(event_id)
      end

      def run
        Enumerator.new do |y|
          y << header.to_s

          reports.each do |rr|
            y << row(rr).to_s
          end
        end
      end

      private

      def reports
        @event.reimbursement_reports.visible.order(created_at: :asc).includes(
          :user,
          :expenses,
          :payout_holding,
        )
      end

      def row(rr)
        ::CSV::Row.new(
          headers,
          [
            rr.created_at,
            rr.status_text,
            rr.name,
            rr.amount_cents,
            rr.user.name,
            rr.user.email
          ]
        )
      end

      def header
        ::CSV::Row.new(headers, headers, true)
      end

      def headers
        [:date, :status, :name, :amount_cents, :reimbursee_name, :reimbursee_email]
      end

    end
  end
end
