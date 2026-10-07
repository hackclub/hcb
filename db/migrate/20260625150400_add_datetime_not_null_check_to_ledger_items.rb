# frozen_string_literal: true

class AddDatetimeNotNullCheckToLedgerItems < ActiveRecord::Migration[8.0]
  def change
    # Add the NOT NULL guard as a check constraint first (NOT VALID) so it
    # doesn't scan/lock the table. It's validated in a later migration before
    # being promoted to a real NOT NULL on the column.
    add_check_constraint :ledger_items, "datetime IS NOT NULL", name: "ledger_items_datetime_null", validate: false
  end

end
