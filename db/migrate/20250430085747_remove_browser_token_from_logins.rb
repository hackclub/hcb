class RemoveBrowserTokenFromLogins < ActiveRecord::Migration[7.0]
  def change
    remove_column :logins, :browser_token, :string
  end
end
