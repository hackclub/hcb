class AddV2ColumnToDisbursement < ActiveRecord::Migration[7.2]
  def change
    add_column :disbursements, :is_v2, :boolean, default: false, null: false
  end
end
