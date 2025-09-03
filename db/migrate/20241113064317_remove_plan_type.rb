class RemovePlanType < ActiveRecord::Migration[7.2]
  def change
    safety_assured { remove_column :event_plans, :plan_type }
  end
end
