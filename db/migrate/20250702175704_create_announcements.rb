class CreateAnnouncements < ActiveRecord::Migration[7.2]
  def change
    create_table :announcements do |t|
      t.string :title
      t.bigint :user_id
      t.bigint :event_id
      t.boolean :draft
      t.boolean :published_at
      t.timestamp :deleted_at

      t.timestamps
    end
  end
end
