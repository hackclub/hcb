class AddUniqueIndexToColumnAccountNumbersOnEventId < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    remove_index :column_account_numbers, :event_id

    add_index :column_account_numbers, :event_id, unique: true, algorithm: :concurrently
  end
end
