# frozen_string_literal: true

class AddLedgerItemPinIdToHcbCodePins < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    # Step 1: Add the column and a concurrently-built index, without a foreign key
    # (added and validated in separate migrations to avoid blocking writes).
    add_reference :hcb_code_pins, :ledger_item_pin, null: true, index: { algorithm: :concurrently }
  end

end
