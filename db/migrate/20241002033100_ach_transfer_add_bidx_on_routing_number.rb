class AchTransferAddBidxOnRoutingNumber < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_column :ach_transfers, :account_number_bidx, :string
    add_index :ach_transfers, :account_number_bidx, algorithm: :concurrently
    add_column :ach_transfers, :routing_number_bidx, :string
    add_index :ach_transfers, :routing_number_bidx, algorithm: :concurrently
  end
end
