# frozen_string_literal: true

module Admin
  class DetectBalanceAnomaliesJob < ApplicationJob
    queue_as :low

    def perform
      anomalous_events = []
      anomalous_card_grants = []
      Ledger.find_each do |ledger|
        if ledger.event.present?
          event = ledger.event
          if event.ledger.balance_cents != event.balance_v2_cents
            anomalous_events << {
              id: event.id,
              slug: event.slug,
              name: event.name,
              balance_v2_cents: event.balance_v2_cents,
              ledger_balance_cents: event.ledger.balance_cents
            }
            puts "Found anomaly on event #{event.id}"
          end
        elsif ledger.card_grant.present?
          card_grant = ledger.card_grant
          if ledger.balance_cents != card_grant.subledger.balance_cents
            anomalous_card_grants << {
              id: card_grant.id,
              hashid: card_grant.hashid,
              name: "Grant to #{card_grant.user.name}",
              card_grant_balance_cents: card_grant.subledger.balance_cents,
              ledger_balance_cents: ledger.balance_cents
            }
            puts "Found anomaly on card grant #{card_grant.id}"
          end
        end
      end

      Rails.cache.write("event_balance_anomalies", anomalous_events)
      Rails.cache.write("card_grant_balance_anomalies", anomalous_card_grants)

      AdminMailer.balance_anomalies(anomalous_events:, anomalous_card_grants:).deliver_now
    end

  end
end
