class RemoveUniqueReferralAttributionsUserLinkIndex < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    remove_index :referral_attributions,
                 [:user_id, :referral_link_id],
                 unique: true,
                 algorithm: :concurrently
  end
end
