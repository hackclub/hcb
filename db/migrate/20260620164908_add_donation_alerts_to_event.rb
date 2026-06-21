class AddDonationAlertsToEvent < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :donation_alerts_enabled, :boolean, default: false
  end
end
