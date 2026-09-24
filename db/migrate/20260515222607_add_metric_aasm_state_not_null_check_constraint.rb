class AddMetricAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :metrics, "aasm_state IS NOT NULL", name: "metrics_aasm_state_null", validate: false
  end
end
