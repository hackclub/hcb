# frozen_string_literal: true

class AddPendingAtAndSettledAtToLedgerItems < ActiveRecord::Migration[8.1]
  def change
    add_column :ledger_items, :pending_at, :datetime
    add_column :ledger_items, :settled_at, :datetime
  end

end
