class ValidateMetricAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :metrics, name: "metrics_aasm_state_null"
    change_column_null :metrics, :aasm_state, false
    remove_check_constraint :metrics, name: "metrics_aasm_state_null"
  end

  def down
    add_check_constraint :metrics, "aasm_state IS NOT NULL", name: "metrics_aasm_state_null", validate: false
    change_column_null :metrics, :aasm_state, true
  end
end
