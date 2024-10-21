class DropBrowserToken < ActiveRecord::Migration[7.1]
  def change
    safety_assured do
      remove_column :login_codes, :browser_token
    end
  end
end
