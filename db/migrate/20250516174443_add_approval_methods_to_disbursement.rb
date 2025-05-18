class AddApprovalMethodsToDisbursement < ActiveRecord::Migration[7.2]
  def change
    add_column :disbursements, :approval_methods, :jsonb
  end
end
