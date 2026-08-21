# frozen_string_literal: true

module Admin
  class DetectFeeAnomaliesJob < ApplicationJob
    queue_as :low

    def perform
      anomalous_events = []
      Event.find_each do |event|
        if event.ledger.fronted_fee_balance_cents != event.fronted_fee_balance_v2_cents
          anomalous_events << {
            id: event.id,
            slug: event.slug,
            name: event.name,
            fronted_fee_balance_v2_cents: event.fronted_fee_balance_v2_cents,
            fronted_fee_balance_cents: event.ledger.fronted_fee_balance_cents
          }
          puts "Found anomaly on #{event.id}"
        end
      end

      Rails.cache.write("event_fee_anomalies", anomalous_events)

      AdminMailer.fee_anomalies(anomalous_events:).deliver_now
    end

  end
end
