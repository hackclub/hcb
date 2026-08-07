class AddUniqueIndexToCardGrantSettingsOnEventId < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    remove_index :card_grant_settings, :event_id

    add_index :card_grant_settings, :event_id, unique: true, algorithm: :concurrently
  end
end
