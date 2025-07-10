class AddPreAuthorizationRequiredToCardGrantSetting < ActiveRecord::Migration[7.2]
  def change
    add_column :card_grant_settings, :pre_authorization_required, :boolean, default: false, null: false
    add_column :card_grants, :pre_authorization_required, :boolean, default: false, null: false
  end
end
