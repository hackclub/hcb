# frozen_string_literal: true

class EnforceDatetimeNotNullOnLedgerItems < ActiveRecord::Migration[8.0]
  def up
    # Validating the check constraint lets Postgres set NOT NULL on the column
    # without a second full scan.
    validate_check_constraint :ledger_items, name: "ledger_items_datetime_null"
    change_column_null :ledger_items, :datetime, false
    remove_check_constraint :ledger_items, name: "ledger_items_datetime_null"

    # `datetime` is now the source of truth. Drop NOT NULL on the legacy `date`
    # column so it can stop being written once `date` is dropped.
    change_column_null :ledger_items, :date, true
  end

  def down
    change_column_null :ledger_items, :date, false
    add_check_constraint :ledger_items, "datetime IS NOT NULL", name: "ledger_items_datetime_null", validate: false
    change_column_null :ledger_items, :datetime, true
  end

end
