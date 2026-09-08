class AddUserTotpAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :user_totps, "aasm_state IS NOT NULL", name: "user_totps_aasm_state_null", validate: false
  end
end
