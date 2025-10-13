# frozen_string_literal: true

require "json"

module DonationService
  module Export
    class Json
      def initialize(event_id:)
        @event = Event.find(event_id)
      end

      def run
        @event.donations.not_pending.order("created_at desc").map do |donation|
          row(donation)
        end.to_json
      end

      private

      def row(d)
        {
          status: d.aasm_state,
          created_at: d.created_at,
          url: Rails.application.routes.url_helpers.url_for(d.local_hcb_code),
          name: d.name,
          email: d.email,
          amount_cents: d.amount,
          message: d.message,
          referrer: d.referrer,
          utm_source: d.utm_source,
          utm_medium: d.utm_medium,
          utm_campaign: d.utm_campaign,
          utm_term: d.utm_term,
          utm_content: d.utm_content,
          recurring: d.recurring?
        }
      end

    end
  end
end
