class RemoveEventIdFromAffiliations < ActiveRecord::Migration[8.0]
  def change
    safety_assured { remove_column :event_affiliations, :event_id, :bigint, null: false }
  end
end
