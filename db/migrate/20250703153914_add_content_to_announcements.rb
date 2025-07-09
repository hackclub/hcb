class AddContentToAnnouncements < ActiveRecord::Migration[7.2]
  def change
    add_column :announcements, :content, :text, null: false
  end
end
