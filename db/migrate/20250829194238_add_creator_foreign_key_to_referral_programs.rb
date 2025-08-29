class AddCreatorForeignKeyToReferralPrograms < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    add_foreign_key :referral_programs, :users, column: :creator_id, validate: false
    add_index :referral_programs, :creator_id, algorithm: :concurrently
  end

  def down
    remove_foreign_key :referral_programs, column: :creator_id
    remove_index :referral_programs, :creator_id
  end
end
