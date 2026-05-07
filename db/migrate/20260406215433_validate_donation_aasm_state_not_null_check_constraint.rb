class ValidateDonationAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :donations, name: "donations_aasm_state_null"
    change_column_null :donations, :aasm_state, false
    remove_check_constraint :donations, name: "donations_aasm_state_null"
  end

  def down
    add_check_constraint :donations, "aasm_state IS NOT NULL", name: "donations_aasm_state_null", validate: false
    change_column_null :donations, :aasm_state, true
  end
end
