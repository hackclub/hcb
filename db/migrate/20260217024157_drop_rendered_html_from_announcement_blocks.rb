class DropRenderedHtmlFromAnnouncementBlocks < ActiveRecord::Migration[8.0]
  def change
    safety_assured {
      remove_column :announcement_blocks, :rendered_html, :text
      remove_column :announcement_blocks, :rendered_email_html, :text
    }
  end
end
