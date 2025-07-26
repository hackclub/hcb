class AddKeywordLockToCardGrantSetting < ActiveRecord::Migration[7.2]
  def change
    add_column :card_grants, :keyword_lock, :string
    add_column :card_grant_settings, :keyword_lock, :string
  end
end
