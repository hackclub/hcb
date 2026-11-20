# frozen_string_literal: true

# Card locking moves from HcbCode onto Ledger::Item (see
# CardLocking::ChargeBehavior). The item's own settled_at replaces the code's
# card_charge_settled_at, and whether a charge still needs a receipt is the
# item's own missing_receipt logic, so the code's receipt_resolved_at has no
# counterpart here. Nothing is copied over from hcb_codes: the sweep fills the
# new column from scratch (see CardLocking::Deadline for why that can't unlock
# anyone). The hcb_codes columns stay until the move has been verified in
# production, then get dropped.
class AddCardLockingReceiptTimingToLedgerItems < ActiveRecord::Migration[8.1]
  def change
    add_column :ledger_items, :receipt_due_at, :datetime
  end

end
