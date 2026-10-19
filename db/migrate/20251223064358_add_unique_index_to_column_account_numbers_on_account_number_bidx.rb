class AddUniqueIndexToColumnAccountNumbersOnAccountNumberBidx < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    remove_index :column_account_numbers, :account_number_bidx

    add_index :column_account_numbers, :account_number_bidx, unique: true, algorithm: :concurrently
  end
end
