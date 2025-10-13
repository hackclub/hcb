class RenameTheColumnToPayoutType < ActiveRecord::Migration[7.2]
  def change
    safety_assured { remove_column :employee_payments, :transfer_id }
    safety_assured { remove_column :employee_payments, :transfer_type }
    add_column :employee_payments, :payout_id, :bigint
    add_column :employee_payments, :payout_type, :string
  end
end
