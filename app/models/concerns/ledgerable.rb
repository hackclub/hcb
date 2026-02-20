# frozen_string_literal: true

# Shared concern for models that own a Ledger::Item and need to keep it
# synchronised (CanonicalTransaction, CanonicalPendingTransaction).
# Extracts three identical callbacks and the belongs_to declaration.
module Ledgerable
  extend ActiveSupport::Concern

  included do
    belongs_to :ledger_item, optional: true, class_name: "Ledger::Item"

    after_create_commit unless: -> { ledger_item.present? } do
      update(ledger_item: create_ledger_item!(memo:, amount_cents: 0, date: created_at, short_code: local_hcb_code.short_code, hcb_code: local_hcb_code))
    end

    after_commit if: -> { ledger_item.present? } do
      ledger_item.map!
      ledger_item.write_amount_cents!
    end

    after_commit if: -> { previous_changes.key?("ledger_item_id") } do
      old_ledger_item_id = previous_changes["ledger_item_id"].first
      Ledger::Item.find(old_ledger_item_id).write_amount_cents! if old_ledger_item_id.present?
    end
  end
end
