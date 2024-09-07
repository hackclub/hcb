class AddCoverDonationFees < ActiveRecord::Migration[7.1]
  def change
    add_column :event_configurations, :cover_donation_fees, :boolean, default: false 
  end
end
