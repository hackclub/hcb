class RemoveReferralProgramIdFromLogins < ActiveRecord::Migration[8.0]
  def up
    safety_assured { remove_column :logins, :referral_program_id }
  end

  def down
    add_column :logins, :referral_program_id, :bigint
  end
end
