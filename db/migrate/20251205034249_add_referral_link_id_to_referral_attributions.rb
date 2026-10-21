class AddReferralLinkIdToReferralAttributions < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_reference :referral_attributions, :referral_link, index: {algorithm: :concurrently}
  end
end
