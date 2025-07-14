class AddJsonContentToAnnouncements < ActiveRecord::Migration[7.2]
  def change
    add_column :announcements, :json_content, :jsonb, null: false
  end
end
