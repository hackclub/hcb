class AddSubeventPlanToEvent < ActiveRecord::Migration[7.2]
  def change
    add_column :events, :subevent_plan, :string
  end
end
