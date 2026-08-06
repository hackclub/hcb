# frozen_string_literal: true

class AddUniqueIndexToHcbCodePinsOnLedgerItemPinId < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    remove_index :hcb_code_pins, :ledger_item_pin_id, algorithm: :concurrently

    add_index :hcb_code_pins, :ledger_item_pin_id, unique: true, algorithm: :concurrently
  end

end
