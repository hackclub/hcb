class AddLoginAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :logins, "aasm_state IS NOT NULL", name: "logins_aasm_state_null", validate: false
  end
end
