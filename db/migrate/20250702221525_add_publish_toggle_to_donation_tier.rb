class AddPublishToggleToDonationTier < ActiveRecord::Migration[7.2]
  def change
    add_column :donation_tiers, :published, :boolean, default: false, null: false

    reversible do |dir|
      dir.up do
        # Set all existing donation tiers to published
        Donation::Tier.update_all(published: true)
      end

      dir.down do
        # Reset all donation tiers to unpublished
        Donation::Tier.update_all(published: false)
      end
    end
  end
end
