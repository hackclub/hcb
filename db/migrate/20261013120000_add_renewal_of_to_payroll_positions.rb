# frozen_string_literal: true

class AddRenewalOfToPayrollPositions < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_reference :payroll_positions, :renewal_of, index: { algorithm: :concurrently }
  end

end
