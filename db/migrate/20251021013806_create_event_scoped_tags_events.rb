class CreateEventScopedTagsEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :event_scoped_tags_events, id: false do |t|
      t.belongs_to :event, null: false, foreign_key: true
      t.belongs_to :event_scoped_tag, null: false, foreign_key: true

      t.index [:event_scoped_tag_id, :event_id], unique: true

      t.timestamps
    end
  end
end
