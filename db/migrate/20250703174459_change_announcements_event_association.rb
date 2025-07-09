class ChangeAnnouncementsEventAssociation < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    safety_assured { remove_column :announcements, :event_id, :bigint }
    add_reference :announcements, :event, null: false, index: {algorithm: :concurrently}
  end
end
