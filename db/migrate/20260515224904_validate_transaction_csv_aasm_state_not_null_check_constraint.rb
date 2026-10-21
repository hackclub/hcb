class ValidateTransactionCsvAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :transaction_csvs, name: "transaction_csvs_aasm_state_null"
    change_column_null :transaction_csvs, :aasm_state, false
    remove_check_constraint :transaction_csvs, name: "transaction_csvs_aasm_state_null"
  end

  def down
    add_check_constraint :transaction_csvs, "aasm_state IS NOT NULL", name: "transaction_csvs_aasm_state_null", validate: false
    change_column_null :transaction_csvs, :aasm_state, true
  end
end
