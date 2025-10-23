class AddBrowserTokenToLogins < ActiveRecord::Migration[7.1]
  def change
    add_column :logins, :browser_token, :string
  end
end
