class AddPublishToggleToDonationTier < ActiveRecord::Migration[7.2]
  def change
    add_column :donation_tiers, :published, :boolean, default: true, null: false
  end
end
