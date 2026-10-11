class AddSessionForeignKeyToReferralAttributions < ActiveRecord::Migration[8.0]
  def change
    add_foreign_key :referral_attributions, :user_sessions, column: :user_session_id, validate: false
  end
end
