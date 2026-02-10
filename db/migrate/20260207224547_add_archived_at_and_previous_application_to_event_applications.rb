class AddArchivedAtAndPreviousApplicationToEventApplications < ActiveRecord::Migration[8.0]
  def change
    add_column :event_applications, :archived_at, :datetime
    add_column :event_applications, :previous_application, :boolean
  end
end
