class AddBlindIndexToReceipt < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!
  
  def change
    add_column :receipts, :textual_content_bidx, :string
    add_index :receipts, :textual_content_bidx, algorithm: :concurrently
  end
end
