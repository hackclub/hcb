class AddBidxColumnAccountNumbers < ActiveRecord::Migration[7.1]
  def change
    add_column :column_account_numbers, :account_number_bidx, :string
  end
end
