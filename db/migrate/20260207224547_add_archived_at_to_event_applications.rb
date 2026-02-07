class AddArchivedAtToEventApplications < ActiveRecord::Migration[8.0]
  def change
    add_column :event_applications, :archived_at, :datetime
  end
end
