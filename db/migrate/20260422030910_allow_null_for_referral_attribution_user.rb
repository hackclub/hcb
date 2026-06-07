class AllowNullForReferralAttributionUser < ActiveRecord::Migration[8.0]
  def change
    change_column_null :referral_attributions, :user_id, true
  end
end
