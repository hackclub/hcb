# frozen_string_literal: true

class EnforceStatusNotNullOnLedgerItems < ActiveRecord::Migration[8.1]
  def up
    # Validating the check constraint lets Postgres set NOT NULL on the column
    # without a second full scan.
    validate_check_constraint :ledger_items, name: "ledger_items_status_null"
    change_column_null :ledger_items, :status, false
    remove_check_constraint :ledger_items, name: "ledger_items_status_null"
  end

  def down
    add_check_constraint :ledger_items, "status IS NOT NULL", name: "ledger_items_status_null", validate: false
    change_column_null :ledger_items, :status, true
  end

end
