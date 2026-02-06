class ChangeReferralAttributionsIndex < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    remove_index :referral_attributions,
                 name: "index_referral_attributions_on_user_id_and_referral_program_id"

    add_index :referral_attributions,
              [:user_id, :referral_link_id],
              unique: true,
              name: "index_referral_attributions_on_user_id_and_referral_link_id",
              algorithm: :concurrently
  end
end
