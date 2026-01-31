class MakeReferralLinkIdNotNullOnReferralAttributions < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :referral_attributions, "referral_link_id IS NOT NULL", name: "referral_attributions_referral_link_id_null", validate: false
  end
end
