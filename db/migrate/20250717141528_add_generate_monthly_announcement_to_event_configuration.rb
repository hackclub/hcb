class AddGenerateMonthlyAnnouncementToEventConfiguration < ActiveRecord::Migration[7.2]
  def change
    add_column :event_configurations, :generate_monthly_announcement, :boolean, null: false, default: false
  end
end
