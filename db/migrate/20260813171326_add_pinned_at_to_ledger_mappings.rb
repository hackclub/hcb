# frozen_string_literal: true

class AddPinnedAtToLedgerMappings < ActiveRecord::Migration[8.1]
  def change
    add_column :ledger_mappings, :pinned_at, :datetime
  end

end
