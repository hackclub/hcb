class AddEventAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :events, "aasm_state IS NOT NULL", name: "events_aasm_state_null", validate: false
  end
end
