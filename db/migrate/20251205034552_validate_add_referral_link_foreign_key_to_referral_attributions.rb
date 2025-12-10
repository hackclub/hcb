class ValidateAddReferralLinkForeignKeyToReferralAttributions < ActiveRecord::Migration[8.0]
  def change
    validate_foreign_key :referral_attributions, :referral_links
  end
end
