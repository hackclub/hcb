class AddDiscordGuildIdAndDiscordChannelIdToEvent < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_column :events, :discord_guild_id, :string
    add_index :events, :discord_guild_id, unique: true, algorithm: :concurrently

    add_column :events, :discord_channel_id, :string
    add_index :events, :discord_channel_id, unique: true, algorithm: :concurrently
  end
end
