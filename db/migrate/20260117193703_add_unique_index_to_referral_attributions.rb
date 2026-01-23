class AddUniqueIndexToReferralAttributions < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :referral_attributions, [:user_id, :referral_program_id], unique: true, algorithm: :concurrently
  end
end
