class ValidateMailboxAddressAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :mailbox_addresses, name: "mailbox_addresses_aasm_state_null"
    change_column_null :mailbox_addresses, :aasm_state, false
    remove_check_constraint :mailbox_addresses, name: "mailbox_addresses_aasm_state_null"
  end

  def down
    add_check_constraint :mailbox_addresses, "aasm_state IS NOT NULL", name: "mailbox_addresses_aasm_state_null", validate: false
    change_column_null :mailbox_addresses, :aasm_state, true
  end
end
