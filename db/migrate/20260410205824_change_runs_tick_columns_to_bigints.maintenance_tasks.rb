# frozen_string_literal: true

# This migration comes from maintenance_tasks (originally 20220706101937)
class ChangeRunsTickColumnsToBigints < ActiveRecord::Migration[7.0]
  def up
    safety_assured do
      change_table(:maintenance_tasks_runs, bulk: true) do |t|
        t.change(:tick_count, :bigint)
        t.change(:tick_total, :bigint)
      end
    end
  end

  def down
    safety_assured do
      change_table(:maintenance_tasks_runs, bulk: true) do |t|
        t.change(:tick_count, :integer)
        t.change(:tick_total, :integer)
      end
    end
  end
end
