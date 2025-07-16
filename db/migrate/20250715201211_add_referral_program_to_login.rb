class AddReferralProgramToLogin < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :logins, :referral_program, null: true, index: { algorithm: :concurrently }
  end
end
