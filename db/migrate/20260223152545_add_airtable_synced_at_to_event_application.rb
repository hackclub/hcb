class AddAirtableSyncedAtToEventApplication < ActiveRecord::Migration[8.0]
  def change
    add_column :event_applications, :airtable_synced_at, :datetime
  end
end
