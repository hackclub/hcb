class AddRenderedHtmlToAnnouncements < ActiveRecord::Migration[7.2]
  def change
    add_column :announcements, :rendered_html, :text
  end
end
