class AddDocumentAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :documents, "aasm_state IS NOT NULL", name: "documents_aasm_state_null", validate: false
  end
end
