# frozen_string_literal: true

class AddRateUnitToPayrollPositions < ActiveRecord::Migration[8.0]
  def change
    add_column :payroll_positions, :rate_unit, :string, default: "hour", null: false
  end

end
