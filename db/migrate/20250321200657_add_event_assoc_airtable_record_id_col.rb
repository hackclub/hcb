class AddEventAssocAirtableRecordIdCol < ActiveRecord::Migration[7.2]
  def change
    add_column :events, :application_airtable_record_id, :string
    add_index :events, :application_airtable_record_id, unique: true, algorithm: :concurrently
  end
end
