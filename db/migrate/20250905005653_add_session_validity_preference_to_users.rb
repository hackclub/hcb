class AddSessionValidityPreferenceToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :session_validity_preference, :integer, null: false, default: 60 * 24 * 3
  end
end
