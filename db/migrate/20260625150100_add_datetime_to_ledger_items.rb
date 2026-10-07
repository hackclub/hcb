# frozen_string_literal: true

class AddDatetimeToLedgerItems < ActiveRecord::Migration[8.0]
  def change
    # Renaming `date` -> `datetime` without downtime: add the new column
    # nullable first. It's backfilled and kept in sync in later steps before
    # becoming NOT NULL and replacing `date`.
    add_column :ledger_items, :datetime, :datetime
  end

end
