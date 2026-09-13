class AddCombineContractAttachmentToPayrollPosition < ActiveRecord::Migration[8.1]
  def change
    add_column :payroll_positions, :combine_contract_attachment, :boolean, null: false, default: true
  end
end
