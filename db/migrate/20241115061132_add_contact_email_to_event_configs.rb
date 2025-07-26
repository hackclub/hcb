class AddContactEmailToEventConfigs < ActiveRecord::Migration[7.2]
  def change
    add_column :event_configurations, :contact_email, :string
  end
end
