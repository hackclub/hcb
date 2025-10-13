class AddTransfersToContractorPayment < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!
  def change
    add_column :employee_payments, :transfer_id, :bigint
    add_column :employee_payments, :transfer_type, :string
  end
end
