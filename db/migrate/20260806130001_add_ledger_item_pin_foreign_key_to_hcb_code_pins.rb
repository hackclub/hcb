# frozen_string_literal: true

class AddLedgerItemPinForeignKeyToHcbCodePins < ActiveRecord::Migration[8.1]
  def change
    # Step 2: Add the foreign key without validating existing rows
    # (validated in a separate migration to avoid locking the table).
    add_foreign_key :hcb_code_pins, :ledger_item_pins, validate: false
  end

end
