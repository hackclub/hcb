class ValidateDocumentAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :documents, name: "documents_aasm_state_null"
    change_column_null :documents, :aasm_state, false
    remove_check_constraint :documents, name: "documents_aasm_state_null"
  end

  def down
    add_check_constraint :documents, "aasm_state IS NOT NULL", name: "documents_aasm_state_null", validate: false
    change_column_null :documents, :aasm_state, true
  end
end
