class AddEventForeignKeyToAnnouncements < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :announcements, :events, validate: false
  end
end
