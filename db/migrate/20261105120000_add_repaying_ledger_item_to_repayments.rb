# frozen_string_literal: true

class AddRepayingLedgerItemToRepayments < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    change_column_null :repayments, :disbursement_id, true

    add_reference :repayments, :repaying_ledger_item, index: { unique: true, algorithm: :concurrently }
    add_reference :repayments, :created_by, index: { algorithm: :concurrently }

    add_foreign_key :repayments, :ledger_items, column: :repaying_ledger_item_id, validate: false
    validate_foreign_key :repayments, :ledger_items, column: :repaying_ledger_item_id
    add_foreign_key :repayments, :users, column: :created_by_id, validate: false
    validate_foreign_key :repayments, :users, column: :created_by_id

    # A repayment is either an HCB transfer or money already on the ledger, never both.
    add_check_constraint :repayments, "num_nonnulls(disbursement_id, repaying_ledger_item_id) = 1",
                         name: "repayments_disbursement_or_repaying_ledger_item", validate: false
    validate_check_constraint :repayments, name: "repayments_disbursement_or_repaying_ledger_item"
  end

end
