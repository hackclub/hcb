class CreateEventScopedTags < ActiveRecord::Migration[7.2]
  def change
    create_table :event_scoped_tags do |t|
      t.string :name, null: false

      t.timestamps
    end
  end
end
