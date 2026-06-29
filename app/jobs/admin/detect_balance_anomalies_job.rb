# frozen_string_literal: true

module Admin
  class DetectBalanceAnomaliesJob < ApplicationJob
    queue_as :low

    def perform
      anomalous_events = []
      Event.find_each do |event|
        if event.ledger.balance_cents != event.balance_v2_cents
          anomalous_events << {
            id: event.id,
            slug: event.slug,
            name: event.name,
            balance_v2_cents: event.balance_v2_cents,
            ledger_balance_cents: event.ledger.balance_cents
          }
          puts "Found anomaly on #{event.id}"
        end
      end

      Rails.cache.write("event_balance_anomalies", anomalous_events)

      AdminMailer.balance_anomalies(anomalous_events:).deliver_now
    end

  end
end
