# frozen_string_literal: true

module CardLocking
  # Materializes a settled card charge's card-locking timing. Idempotent; enqueued
  # from both transaction engines' mapping hooks. Trust-based sliding is applied
  # later by the recurring sweep, so this uses the default (untrusted) deadline.
  class MaterializeChargeJob < ApplicationJob
    queue_as :low

    # hcb_code_id is only passed by jobs enqueued before card locking moved onto
    # ledger items; drop it once none are left in the queue.
    def perform(ledger_item_id: nil, hcb_code_id: nil)
      ledger_item_id ||= HcbCode.find_by(id: hcb_code_id)&.ledger_item_id
      ledger_item = Ledger::Item.find_by(id: ledger_item_id)
      return unless ledger_item

      ledger_item.materialize_card_locking!(now: Time.current)
    end

  end
end
