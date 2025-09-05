class AddReferralLinkIdToReferralAttributions < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :referral_attributions, :referral_link, null: false, index: {algorithm: :concurrently}
  end
end
