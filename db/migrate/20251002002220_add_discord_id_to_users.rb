class AddDiscordIdToUsers < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_column :users, :discord_id, :string, null: true
    add_index :users, :discord_id, unique: true, algorithm: :concurrently
  end
end
