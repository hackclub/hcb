# frozen_string_literal: true

class Ledger
  class AssertCorrectLedgerBalancesJob < ApplicationJob
    queue_as :low
    include AssertsRequirements

    def run
      @ledgers = Ledger.all.includes(event: :ledger, card_grant: [:subledger, :user])

      @ledgers.find_each do |ledger|
        safely do
          if ledger.event.present?
            event = ledger.event
            if event.ledger.balance_cents != event.balance_v2_cents
              report_anomaly "Event #{event.id} (#{event.slug}) balance_v2_cents #{event.balance_v2_cents} does not match ledger balance_cents #{event.ledger.balance_cents}"
            end
          elsif ledger.card_grant.present?
            card_grant = ledger.card_grant
            if ledger.balance_cents != card_grant.subledger.balance_cents
              report_anomaly "CardGrant #{card_grant.hashid} ledger balance_cents #{ledger.balance_cents} does not match subledger balance_cents #{card_grant.subledger.balance_cents}"
            end
          end
        end
      end
    end

  end

end
