# frozen_string_literal: true

class AddCardLockingReceiptTiming < ActiveRecord::Migration[8.0]
  def change
    add_column :hcb_codes, :receipt_settled_at, :datetime
    add_column :hcb_codes, :receipt_due_at, :datetime
    add_column :hcb_codes, :receipt_resolved_at, :datetime
    add_column :users, :card_locking_suppressed_until, :datetime
  end
end
