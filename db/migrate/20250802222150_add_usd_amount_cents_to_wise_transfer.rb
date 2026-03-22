class AddUsdAmountCentsToWiseTransfer < ActiveRecord::Migration[7.2]
  def change
    add_column :wise_transfers, :usd_amount_cents, :integer
  end
end
