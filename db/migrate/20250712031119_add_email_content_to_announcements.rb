class AddEmailContentToAnnouncements < ActiveRecord::Migration[7.2]
  def change
    add_column :announcements, :rendered_email_html, :text
  end
end
