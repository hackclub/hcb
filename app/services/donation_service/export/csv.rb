# frozen_string_literal: true

require "csv"

module DonationService
  module Export
    class Csv
      def initialize(event_id:)
        @event = Event.find(event_id)
      end

      def run
        Enumerator.new do |csv|
          csv << headers.to_csv

          @event.donations.not_pending.order("created_at desc").each do |donation|
            csv << row(donation).to_csv
          end
        end
      end

      private

      def headers
        %w[status date url name email amount_cents recurring]
      end

      def row(d)
        [d.aasm_state, d.created_at, Rails.application.routes.url_helpers.url_for(d.local_hcb_code), d.name, d.email, d.amount, d.recurring?]
      end

    end
  end
end
