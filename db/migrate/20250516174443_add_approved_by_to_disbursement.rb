class AddApprovedByToDisbursement < ActiveRecord::Migration[7.2]
  def change
    add_column :disbursements, :approved_by, :jsonb
  end
end
