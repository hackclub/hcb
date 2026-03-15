class AddAasmStateToMetric < ActiveRecord::Migration[8.0]
  def change
    add_column :metrics, :aasm_state, :string
  end
end
