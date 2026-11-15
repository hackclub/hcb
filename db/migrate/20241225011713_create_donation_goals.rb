class CreateDonationGoals < ActiveRecord::Migration[6.1]
  def change
    create_table :donation_goals do |t|
      t.references :event, null: false, foreign_key: true
      t.integer :amount_cents, null: false
      t.datetime :tracking_since, null: false
      t.datetime :deleted_at
      t.timestamps
    end
  end
end
