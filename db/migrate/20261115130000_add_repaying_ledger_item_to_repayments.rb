# frozen_string_literal: true

class AddRepayingLedgerItemToRepayments < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # Each step commits on its own, so they're safe to re-run after a lock timeout.
  def up
    change_column_null :repayments, :disbursement_id, true

    add_reference :repayments, :repaying_ledger_item, index: { unique: true, algorithm: :concurrently, if_not_exists: true }, if_not_exists: true
    add_reference :repayments, :created_by, index: { algorithm: :concurrently, if_not_exists: true }, if_not_exists: true

    add_foreign_key :repayments, :ledger_items, column: :repaying_ledger_item_id, validate: false, if_not_exists: true
    validate_foreign_key :repayments, :ledger_items, column: :repaying_ledger_item_id
    add_foreign_key :repayments, :users, column: :created_by_id, validate: false, if_not_exists: true
    validate_foreign_key :repayments, :users, column: :created_by_id

    # A repayment is either an HCB transfer or money already on the ledger, never both.
    add_check_constraint :repayments, "num_nonnulls(disbursement_id, repaying_ledger_item_id) = 1",
                         name: "repayments_disbursement_or_repaying_ledger_item", validate: false, if_not_exists: true
    validate_check_constraint :repayments, name: "repayments_disbursement_or_repaying_ledger_item"
  end

  def down
    # Rolling back would drop these links and then fail to make disbursement_id required again.
    if select_value("SELECT 1 FROM repayments WHERE disbursement_id IS NULL LIMIT 1")
      raise ActiveRecord::IrreversibleMigration, "repayments marked between two transactions exist; remove them first"
    end

    remove_check_constraint :repayments, name: "repayments_disbursement_or_repaying_ledger_item"
    remove_reference :repayments, :created_by, foreign_key: { to_table: :users }, index: true
    remove_reference :repayments, :repaying_ledger_item, foreign_key: { to_table: :ledger_items }, index: true
    change_column_null :repayments, :disbursement_id, false
  end

end
