class AddTransactionCsvAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :transaction_csvs, "aasm_state IS NOT NULL", name: "transaction_csvs_aasm_state_null", validate: false
  end
end
