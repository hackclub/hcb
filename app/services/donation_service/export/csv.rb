# frozen_string_literal: true

require "csv"

module DonationService
  module Export
    class Csv
      BATCH_SIZE = 1000

      def initialize(event_id:)
        @event_id = event_id
      end

      def run
        Enumerator.new do |y|
          y << header.to_s

          event.donations.not_pending.order("created_at desc").each do |donation|
            y << row(donation).to_s
          end
        end
      end

      private

      def event
        @event ||= Event.find(@event_id)
      end

      def header
        ::CSV::Row.new(headers, ["status", "date", "url", "name", "email", "amount_cents"], true)
      end

      def row(ct)
        ::CSV::Row.new(headers, [ct.aasm_state, ct.created_at, "https://hcb.hackclub.com/donations/#{ct.id}", ct.name, ct.amount])
      end

      def headers
        [
          :created_at,
          :hcb_code,
          :name,
          :amount
        ]
      end

    end
  end
end
