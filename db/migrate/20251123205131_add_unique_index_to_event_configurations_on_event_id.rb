class AddUniqueIndexToEventConfigurationsOnEventId < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    remove_index :event_configurations, :event_id

    add_index :event_configurations, :event_id, unique: true, algorithm: :concurrently
  end
end
