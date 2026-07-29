# frozen_string_literal: true

class RemoveDateFromLedgerItems < ActiveRecord::Migration[8.0]
  def change
    # Final step of the date -> datetime rename. The column is no longer read
    # or written (see Ledger::Item.ignored_columns), so it's safe to drop along
    # with its index. safety_assured: the column is already ignored by the app.
    safety_assured do
      remove_column :ledger_items, :date, :datetime
    end
  end

end
