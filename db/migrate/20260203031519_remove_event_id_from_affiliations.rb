class RemoveEventIdFromAffiliations < ActiveRecord::Migration[8.0]
  def change
    safety_assured { remove_reference :event_affiliations, :event, null: false, foreign_key: true }
  end
end
