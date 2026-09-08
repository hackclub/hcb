# frozen_string_literal: true

# column_id had no index at all, so every `Column::AccountNumber.find_by(column_id:)`
# lookup (e.g. Ledger::Mapper#event_from_canonical_transactions) was a sequential
# scan of the whole table. Unique because a Column account number belongs to
# exactly one event.
class AddIndexOnColumnIdToColumnAccountNumbers < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :column_account_numbers, :column_id, unique: true, algorithm: :concurrently
  end

end
