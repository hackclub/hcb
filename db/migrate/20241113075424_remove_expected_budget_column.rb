# frozen_string_literal: true

class RemoveExpectedBudgetColumn < ActiveRecord::Migration[7.2]
  def change
    safety_assured { remove_column :events, :expected_budget }
  end

end
