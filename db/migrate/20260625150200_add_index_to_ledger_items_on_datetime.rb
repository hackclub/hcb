# frozen_string_literal: true

class AddIndexToLedgerItemsOnDatetime < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :ledger_items, :datetime, algorithm: :concurrently
  end

end
