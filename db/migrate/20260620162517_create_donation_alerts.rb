class CreateDonationAlerts < ActiveRecord::Migration[8.0]
  def change
    create_table :donation_alerts do |t|
      t.references :event, null: false, foreign_key: true
      t.integer :amount_cents, null: false
      t.string :alert_name
      t.text :alert_message
      t.boolean :active, default: true
      t.timestamps
    end

    # Join table for users subscribed to alerts
    create_join_table :donation_alerts, :users do |t|
      t.index [:donation_alert_id, :user_id], unique: true
      t.timestamps
    end
  end
end