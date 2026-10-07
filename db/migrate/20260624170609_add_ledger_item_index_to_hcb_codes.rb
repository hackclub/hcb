# frozen_string_literal: true

class AddLedgerItemIndexToHcbCodes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :hcb_codes, :ledger_item_id, algorithm: :concurrently
  end
end
