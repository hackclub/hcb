class MakeReferralProgramIdNullableInReferralAttributions < ActiveRecord::Migration[7.2]
  def change
    change_column_null :referral_attributions, :referral_program_id, true
  end
end
