class AddEventPlanAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :event_plans, "aasm_state IS NOT NULL", name: "event_plans_aasm_state_null", validate: false
  end
end
