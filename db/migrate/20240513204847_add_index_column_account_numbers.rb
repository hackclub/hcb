class AddIndexColumnAccountNumbers < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :column_account_numbers, :account_number_bidx, algorithm: :concurrently
  end
end
