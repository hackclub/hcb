class AddEmailToPayee < ActiveRecord::Migration[8.0]
  def change
    add_column :payees, :email, :string, null: false
  end
end
