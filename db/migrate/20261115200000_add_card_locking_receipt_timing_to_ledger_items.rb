# frozen_string_literal: true

# Card locking moves from HcbCode onto Ledger::Item (see
# CardLocking::ChargeBehavior). The hcb_codes copies of these columns stay until
# the move has been verified in production, then get dropped.
class AddCardLockingReceiptTimingToLedgerItems < ActiveRecord::Migration[8.1]
  def change
    change_table :ledger_items, bulk: true do |t|
      t.datetime :card_charge_settled_at
      t.datetime :receipt_due_at
      t.datetime :receipt_resolved_at
    end
  end

end
