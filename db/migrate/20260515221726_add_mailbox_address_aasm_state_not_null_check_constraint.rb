class AddMailboxAddressAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :mailbox_addresses, "aasm_state IS NOT NULL", name: "mailbox_addresses_aasm_state_null", validate: false
  end
end
