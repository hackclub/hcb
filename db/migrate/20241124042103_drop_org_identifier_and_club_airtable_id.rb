class DropOrgIdentifierAndClubAirtableId < ActiveRecord::Migration[7.2]
  def change
    safety_assured { remove_column :events, :organization_identifier }
    safety_assured { remove_column :events, :club_airtable_id }
  end
end
