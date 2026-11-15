class RemoveShowExploreHackClubFromReferralPrograms < ActiveRecord::Migration[7.2]
  def up
    safety_assured { remove_column :referral_programs, :show_explore_hack_club, if_exists: true }
  end

  def down
    add_column :referral_programs, :show_explore_hack_club, :boolean
  end
end
