class ValidateMakeReferralLinkIdNotNullOnReferralAttributions < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :referral_attributions, name: "referral_attributions_referral_link_id_null"
    change_column_null :referral_attributions, :referral_link_id, false
    remove_check_constraint :referral_attributions, name: "referral_attributions_referral_link_id_null"
  end

  def down
    add_check_constraint :referral_attributions, "referral_link_id IS NOT NULL", name: "referral_attributions_referral_link_id_null", validate: false
    change_column_null :referral_attributions, :referral_link_id, true
  end
end
