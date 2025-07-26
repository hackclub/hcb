class AddInactiveAtToEventPlan < ActiveRecord::Migration[7.2]
  def change
    add_column :event_plans, :inactive_at, :datetime
  end
end
