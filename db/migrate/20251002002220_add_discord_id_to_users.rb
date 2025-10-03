class AddDiscordIdToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :discord_id, :string
  end
end
