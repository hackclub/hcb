class AddMemoAndEventIdToFee < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!
  def change
    add_reference :fees, :event, index: {algorithm: :concurrently}
    add_column :fees, :memo, :string
  end
end
