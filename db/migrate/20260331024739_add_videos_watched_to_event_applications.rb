class AddVideosWatchedToEventApplications < ActiveRecord::Migration[8.0]
  def change
    add_column :event_applications, :videos_watched, :boolean
  end
end
