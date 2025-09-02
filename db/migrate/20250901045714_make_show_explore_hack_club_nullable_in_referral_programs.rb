class MakeShowExploreHackClubNullableInReferralPrograms < ActiveRecord::Migration[7.2]
  def change
    change_column_null :referral_programs, :show_explore_hack_club, true
  end
end
