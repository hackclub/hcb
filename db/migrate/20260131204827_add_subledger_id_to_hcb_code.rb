class AddSubledgerIdToHcbCode < ActiveRecord::Migration[8.0]
  def change
    add_column :hcb_codes, :subledger_id, :bigint
  end
end
