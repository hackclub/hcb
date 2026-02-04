class AllowNullInAffiliationEvent < ActiveRecord::Migration[8.0]
  def change
    change_column_null :event_affiliations, :event_id, true
  end
end
