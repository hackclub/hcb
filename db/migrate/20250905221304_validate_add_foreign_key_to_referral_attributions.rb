class ValidateAddForeignKeyToReferralAttributions < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :referral_attributions, :referral_links
  end
end
