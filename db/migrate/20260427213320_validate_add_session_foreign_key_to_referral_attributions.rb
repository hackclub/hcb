class ValidateAddSessionForeignKeyToReferralAttributions < ActiveRecord::Migration[8.0]
  def change
    validate_foreign_key :referral_attributions, :user_sessions
  end
end
