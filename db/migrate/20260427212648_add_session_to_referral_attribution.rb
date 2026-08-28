class AddSessionToReferralAttribution < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_reference :referral_attributions, :user_session, index: {algorithm: :concurrently}
  end
end
