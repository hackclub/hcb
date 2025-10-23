class DropRoutingNumberFromAchTransfer < ActiveRecord::Migration[7.2]
  def change
    safety_assured { remove_column :ach_transfers, :routing_number }
  end
end
