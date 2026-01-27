class AddLocalObjectToRawColumnTransaction < ActiveRecord::Migration[8.0]
  def change
    add_column :raw_column_transactions, :local_object, :jsonb
  end
end
