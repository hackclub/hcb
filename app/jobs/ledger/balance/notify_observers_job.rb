# frozen_string_literal: true

class Ledger
  module Balance
    # Enqueued from the ledger mapping and item hooks whenever a ledger's
    # balance may have changed. Idempotent, so duplicate enqueues are harmless.
    class NotifyObserversJob < ApplicationJob
      queue_as :low

      def perform(ledger_id:)
        ledger = Ledger.find_by(id: ledger_id)
        return unless ledger

        balance_cents = ledger.available_balance_cents
        ledger.balance_observers.find_each { |observer| observer.check!(balance_cents:) }
      end

    end
  end

end
