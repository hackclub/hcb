# frozen_string_literal: true

# Card locking moves from HcbCode onto Ledger::Item (see
# CardLocking::ChargeBehavior). The item's own settled_at replaces the code's
# card_charge_settled_at, and whether a charge is resolved is read live from
# its receipt_count and marked_no_or_lost_receipt_at, so the code's
# receipt_resolved_at has no counterpart here. The hcb_codes copies of the
# columns stay until the move has been verified in production, then get dropped.
class AddCardLockingReceiptTimingToLedgerItems < ActiveRecord::Migration[8.1]
  def change
    add_column :ledger_items, :receipt_due_at, :datetime
  end

end
