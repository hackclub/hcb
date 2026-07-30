class ValidateEventPlanAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :event_plans, name: "event_plans_aasm_state_null"
    change_column_null :event_plans, :aasm_state, false
    remove_check_constraint :event_plans, name: "event_plans_aasm_state_null"
  end

  def down
    add_check_constraint :event_plans, "aasm_state IS NOT NULL", name: "event_plans_aasm_state_null", validate: false
    change_column_null :event_plans, :aasm_state, true
  end
end
