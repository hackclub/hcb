# frozen_string_literal: true

# This migration comes from maintenance_tasks (originally 20210225152418)
class RemoveIndexOnTaskName < ActiveRecord::Migration[7.0]
  def up
    safety_assured do
      change_table(:maintenance_tasks_runs) do |t|
        t.remove_index(:task_name)
      end
    end
  end

  def down
    safety_assured do
      change_table(:maintenance_tasks_runs) do |t|
        t.index(:task_name)
      end
    end
  end
end
