class ValidateAddCreatorForeignKeyToReferralPrograms < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :referral_programs, :users
  end
end
