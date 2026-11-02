# frozen_string_literal: true

class AddStatusToLedgerItems < ActiveRecord::Migration[8.0]
  def change
    add_column :ledger_items, :status, :string
  end

end
