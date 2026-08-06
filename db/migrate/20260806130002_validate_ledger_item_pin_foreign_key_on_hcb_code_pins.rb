# frozen_string_literal: true

class ValidateLedgerItemPinForeignKeyOnHcbCodePins < ActiveRecord::Migration[8.1]
  def change
    # Step 3: Validate the foreign key constraint against existing rows.
    validate_foreign_key :hcb_code_pins, :ledger_item_pins
  end

end
