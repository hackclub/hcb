class AddEmailContentToAnnouncements < ActiveRecord::Migration[7.2]
  def change
    add_column :announcements, :email_content, :text
  end
end
