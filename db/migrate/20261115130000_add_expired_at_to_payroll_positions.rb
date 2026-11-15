# frozen_string_literal: true

class AddExpiredAtToPayrollPositions < ActiveRecord::Migration[8.1]
  def change
    add_column :payroll_positions, :expired_at, :datetime
  end

end
