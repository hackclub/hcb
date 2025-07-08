class ChangeAnnouncementsPublishedAtToDateTime < ActiveRecord::Migration[7.2]
  def change
    # safety_assured { change_column :announcements, :published_at, "time with time zone" }
    safety_assured { remove_column :announcements, :published_at, :boolean }
    add_column :announcements, :published_at, :datetime
  end
end
