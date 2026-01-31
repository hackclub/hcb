class ValidateMakeCreatorIdNotNullOnReferralPrograms < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :referral_programs, name: "referral_programs_creator_id_null"
    change_column_null :referral_programs, :creator_id, false
    remove_check_constraint :referral_programs, name: "referral_programs_creator_id_null"
  end

  def down
    add_check_constraint :referral_programs, "creator_id IS NOT NULL", name: "referral_programs_creator_id_null", validate: false
    change_column_null :referral_programs, :creator_id, true
  end
end
