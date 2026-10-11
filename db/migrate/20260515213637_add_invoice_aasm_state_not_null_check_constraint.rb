class AddInvoiceAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :invoices, "aasm_state IS NOT NULL", name: "invoices_aasm_state_null", validate: false
  end
end
