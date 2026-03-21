class AddAirtableSyncedAtToEventApplication < ActiveRecord::Migration[8.0]
  def change
    add_column :event_applications, :airtable_synced_at, :datetime

    reversible do |direction|
      direction.up do
        Event::Application.find_each do |application|
          application.update!(airtable_synced_at: application.updated_at) if application.airtable_record_id.present?
        end
      end
    end
  end
end
