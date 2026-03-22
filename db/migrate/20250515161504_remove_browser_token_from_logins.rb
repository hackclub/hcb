class RemoveBrowserTokenFromLogins < ActiveRecord::Migration[7.2]
  def change
    safety_assured { remove_column :logins, :browser_token, :string }
  end
end
