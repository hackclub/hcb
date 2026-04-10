class AddDonationAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :donations, "aasm_state IS NOT NULL", name: "donations_aasm_state_null", validate: false
  end
end
