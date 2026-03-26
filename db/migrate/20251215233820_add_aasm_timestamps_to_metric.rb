class AddAasmTimestampsToMetric < ActiveRecord::Migration[8.0]
  def change
    add_column :metrics, :processing_at, :datetime
    add_column :metrics, :completed_at, :datetime
    add_column :metrics, :failed_at, :datetime
    add_column :metrics, :canceled_at, :datetime
  end
end
