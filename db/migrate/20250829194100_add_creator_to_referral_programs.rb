class AddCreatorToReferralPrograms < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    add_reference :referral_programs, :creator, null: false, index: {algorithm: :concurrently}
  end

  def down
    remove_reference :referral_programs, :creator, foreign_key: true
  end
end
