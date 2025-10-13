class ValidateAddEventForeignKeyToAnnouncements < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :announcements, :events
  end
end