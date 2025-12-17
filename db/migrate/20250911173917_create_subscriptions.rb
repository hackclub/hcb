class CreateSubscriptions < ActiveRecord::Migration[7.2]
  def change
    create_table :subscriptions do |t|
      t.string :merchant
      t.string :card
      t.json :hcb_codes
      t.string :last_hcb_code
      t.decimal :average_date_difference

      t.timestamps
    end

    add_index :subscriptions, [:merchant, :card], unique: true
  end
end
