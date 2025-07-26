class AddSubeventPlanToEventConfiguration < ActiveRecord::Migration[7.2]
  def change
    add_column :event_configurations, :subevent_plan, :string
  end
end
