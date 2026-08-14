# frozen_string_literal: true

class Event
  class RefreshLedgersJob < ApplicationJob
    queue_as :low

    # Recomputes `amount_cents` (and other cached fields) for every Ledger::Item
    # belonging to this event, plus its card grants' ledgers. This needs to
    # happen whenever `Event#can_front_balance` changes, since that flag
    # changes how Ledger::Item#calculate_amount_cents treats fronted incoming
    # pending transactions.
    def perform(event_id:)
      Event.find(event_id).refresh_ledgers!
    end

  end

end
