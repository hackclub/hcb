class DropRenderedHtmlFromAnnouncements < ActiveRecord::Migration[7.2]
  def change
    safety_assured do
      remove_column :announcements, :rendered_html, :text
      remove_column :announcements, :rendered_email_html, :text
    end
  end
end
