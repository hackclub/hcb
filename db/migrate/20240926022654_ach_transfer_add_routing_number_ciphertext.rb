class AchTransferAddRoutingNumberCiphertext < ActiveRecord::Migration[7.2]
  def change
    add_column :ach_transfers, :routing_number_ciphertext, :text
  end
end
