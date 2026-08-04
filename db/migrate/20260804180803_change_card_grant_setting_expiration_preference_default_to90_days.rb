class ChangeCardGrantSettingExpirationPreferenceDefaultTo90Days < ActiveRecord::Migration[8.1]
  def change
    change_column_default :card_grant_settings, :expiration_preference, from: 365, to: 90
  end
end
