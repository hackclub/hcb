class AddVideosWatchedToEventApplications < ActiveRecord::Migration[8.0]
  def change
    add_column :event_applications, :videos_watched, :boolean
    change_column_default :event_applications, :videos_watched, from: nil, to: false
  end
end
