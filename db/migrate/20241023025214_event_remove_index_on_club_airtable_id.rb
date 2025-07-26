class EventRemoveIndexOnClubAirtableId < ActiveRecord::Migration[7.2]
  def change
    safety_assured do 
      remove_index :events, name: "index_events_on_club_airtable_id"
    end
  end
end
