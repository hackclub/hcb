class CreateDiscordMessage < ActiveRecord::Migration[7.2]
  def change
    create_table :discord_messages do |t|
      t.string :discord_message_id, null: false, index: { unique: true }
      t.string :discord_channel_id, null: false
      t.string :discord_guild_id, null: false
      t.references :activity, null: true, foreign_key: true

      t.timestamps
    end
  end
end
