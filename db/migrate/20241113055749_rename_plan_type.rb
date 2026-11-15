# frozen_string_literal: true

class RenamePlanType < ActiveRecord::Migration[7.2]
  def up
    add_column :event_plans, :type, :string
    Event::Plan.update_all("type = plan_type")
  end

  def down
    remove_column :event_plans, :type
  end

end
