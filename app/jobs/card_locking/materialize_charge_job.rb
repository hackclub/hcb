# frozen_string_literal: true

module CardLocking
  # Materializes a settled card charge's card-locking timing. Idempotent; enqueued
  # from both transaction engines' mapping hooks. Trust-based sliding is applied
  # later by the recurring sweep, so this uses the default (untrusted) deadline.
  class MaterializeChargeJob < ApplicationJob
    queue_as :low

    # Jobs enqueued before card locking moved onto ledger items name the charge
    # by hcb_code_id instead. Those are dropped rather than looked up: the sweep
    # (UserService::RefreshReceiptDeadlines) materializes every outstanding
    # charge within minutes anyway. Remove the splat once the queue has drained.
    def perform(ledger_item_id: nil, **)
      ledger_item = Ledger::Item.find_by(id: ledger_item_id)
      return unless ledger_item

      ledger_item.materialize_card_locking!(now: Time.current)
    end

  end
end
