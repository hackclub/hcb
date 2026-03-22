class CreateEventScopedTags < ActiveRecord::Migration[7.2]
  def change
    create_table :event_scoped_tags do |t|
      t.string :name, null: false
      t.references :parent_event, null: false, foreign_key: { to_table: :events }

      t.timestamps
    end
  end
end
