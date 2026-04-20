class ValidateEventAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :events, name: "events_aasm_state_null"
    change_column_null :events, :aasm_state, false
    remove_check_constraint :events, name: "events_aasm_state_null"
  end

  def down
    add_check_constraint :events, "aasm_state IS NOT NULL", name: "events_aasm_state_null", validate: false
    change_column_null :events, :aasm_state, true
  end
end
