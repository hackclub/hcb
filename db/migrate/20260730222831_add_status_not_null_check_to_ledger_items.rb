# frozen_string_literal: true

class AddStatusNotNullCheckToLedgerItems < ActiveRecord::Migration[8.1]
  def change
    # Add the NOT NULL guard as a check constraint first (NOT VALID) so it
    # doesn't scan/lock the table. It's validated in the next migration before
    # being promoted to a real NOT NULL on the column.
    add_check_constraint :ledger_items, "status IS NOT NULL", name: "ledger_items_status_null", validate: false
  end

end
