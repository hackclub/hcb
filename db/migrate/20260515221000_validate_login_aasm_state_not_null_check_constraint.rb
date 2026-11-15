class ValidateLoginAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :logins, name: "logins_aasm_state_null"
    change_column_null :logins, :aasm_state, false
    remove_check_constraint :logins, name: "logins_aasm_state_null"
  end

  def down
    add_check_constraint :logins, "aasm_state IS NOT NULL", name: "logins_aasm_state_null", validate: false
    change_column_null :logins, :aasm_state, true
  end
end
