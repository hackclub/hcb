class AddClassificationToPayment < ActiveRecord::Migration[8.1]
  def change
    add_column :payments, :classification, :string, null: false, default: "other_services"
  end
end
