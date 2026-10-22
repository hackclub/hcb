# frozen_string_literal: true

# `SET DEFAULT` only applies to newly inserted rows, so items created before
# `status` existed still need a value before NOT NULL can be enforced. `pending`
# is both the new column default and what `calculate_status` falls back to; each
# item's real status lands on its next refresh.
class BackfillLedgerItemStatuses < ActiveRecord::Migration[8.1]
  def up
    Ledger::Item.where(status: nil).update_all(status: "pending")
  end

  def down
    # Irreversible: which rows were NULL isn't recoverable, and NULL only ever
    # meant "not computed yet".
  end

end
