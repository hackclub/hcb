class UpdateUserSessionTypes < ActiveRecord::Migration[8.0]
  def up
    PublicActivity::Activity.where(trackable_type: "UserSession").update_all(trackable_type: "User::Session")
    PaperTrail::Version.where(item_type: "UserSession").update_all(item_type: "User::Session")
  end

  def down
    PublicActivity::Activity.where(trackable_type: "User::Session").update_all(trackable_type: "UserSession")
    PaperTrail::Version.where(item_type: "User::Session").update_all(item_type: "UserSession")
  end
end
