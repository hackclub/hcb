class AddInvoicedAtToAchTransfers < ActiveRecord::Migration[7.2]
  def change
    add_column :ach_transfers, :invoiced_at, :date
  end
end
