class ChangeAnnouncementsPublishedAtToDateTime < ActiveRecord::Migration[7.2]
  def change
    safety_assured { remove_column :announcements, :published_at, :boolean }
    add_column :announcements, :published_at, :datetime
  end
end
