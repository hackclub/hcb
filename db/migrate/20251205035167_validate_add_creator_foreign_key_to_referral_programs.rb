class ValidateAddCreatorForeignKeyToReferralPrograms < ActiveRecord::Migration[8.0]
  def change
    validate_foreign_key :referral_programs, :users, column: :creator_id
  end
end
