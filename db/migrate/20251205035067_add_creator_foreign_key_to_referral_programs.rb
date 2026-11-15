class AddCreatorForeignKeyToReferralPrograms < ActiveRecord::Migration[8.0]
  def change
    add_foreign_key :referral_programs, :users, column: :creator_id, validate: false
  end
end
