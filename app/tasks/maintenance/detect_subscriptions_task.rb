# frozen_string_literal: true

module Maintenance
  # Backfills subscriptions by running detection on every settled card charge
  # that isn't linked yet, oldest first. Safe to re-run.
  class DetectSubscriptionsTask < MaintenanceTasks::Task
    def collection
      Ledger::Item.settled.where(linked_object_type: CardCharge.name, subscription_id: nil, amount_cents: ...0)
    end

    def process(ledger_item)
      Subscription::Detect.new(ledger_item).run
    end

  end
end
