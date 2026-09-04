class AddManagerToPayrollPosition < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!
  
  def change
    add_reference :payroll_positions, :manager, index: {algorithm: :concurrently}
  end
end
