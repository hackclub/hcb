class ValidateUserTotpAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :user_totps, name: "user_totps_aasm_state_null"
    change_column_null :user_totps, :aasm_state, false
    remove_check_constraint :user_totps, name: "user_totps_aasm_state_null"
  end

  def down
    add_check_constraint :user_totps, "aasm_state IS NOT NULL", name: "user_totps_aasm_state_null", validate: false
    change_column_null :user_totps, :aasm_state, true
  end
end
