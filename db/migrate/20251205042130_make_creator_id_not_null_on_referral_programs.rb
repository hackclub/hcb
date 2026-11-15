class MakeCreatorIdNotNullOnReferralPrograms < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :referral_programs, "creator_id IS NOT NULL", name: "referral_programs_creator_id_null", validate: false
  end
end
