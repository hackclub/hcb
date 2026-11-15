class CreateAnnouncements < ActiveRecord::Migration[7.2]
  def change
    create_table :announcements do |t|
      t.string :title, null: false
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.bigint :event_id, null: false
      t.boolean :published_at
      t.timestamp :deleted_at

      t.timestamps
    end
  end
end
