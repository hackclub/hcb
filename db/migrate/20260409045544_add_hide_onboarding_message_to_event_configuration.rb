class AddHideOnboardingMessageToEventConfiguration < ActiveRecord::Migration[8.0]
  def change
    add_column :event_configurations, :hide_onboarding_message, :boolean, null: false, default: true
    change_column_default :event_configurations, :hide_onboarding_message, from: true, to: false
  end
end
