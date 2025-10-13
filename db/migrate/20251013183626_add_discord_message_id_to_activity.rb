class AddDiscordMessageIdToActivity < ActiveRecord::Migration[7.2]
  def change
    add_column :activities, :discord_message_id, :string
  end
end
