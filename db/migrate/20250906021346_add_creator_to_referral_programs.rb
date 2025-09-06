class AddCreatorToReferralPrograms < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :referral_programs, :creator, index: {algorithm: :concurrently}
  end
end
