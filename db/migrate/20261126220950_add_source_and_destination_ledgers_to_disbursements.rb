# frozen_string_literal: true

# A disbursement moves money from one ledger to another, but the row only
# records the events and subledgers on each side, so every reader has to work
# out which ledger they mean (https://github.com/hackclub/hcb/issues/14163).
# Record the ledgers directly. Nullable until existing rows are backfilled; the
# event and subledger columns stay until the readers have switched.
class AddSourceAndDestinationLedgersToDisbursements < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # Each step commits on its own, so they're safe to re-run after a lock timeout.
  def up
    add_reference :disbursements, :source_ledger, index: { algorithm: :concurrently, if_not_exists: true }, if_not_exists: true
    add_reference :disbursements, :destination_ledger, index: { algorithm: :concurrently, if_not_exists: true }, if_not_exists: true

    add_foreign_key :disbursements, :ledgers, column: :source_ledger_id, validate: false, if_not_exists: true
    add_foreign_key :disbursements, :ledgers, column: :destination_ledger_id, validate: false, if_not_exists: true
    validate_foreign_key :disbursements, column: :source_ledger_id
    validate_foreign_key :disbursements, column: :destination_ledger_id
  end

  def down
    remove_reference :disbursements, :source_ledger, foreign_key: { to_table: :ledgers }, index: true
    remove_reference :disbursements, :destination_ledger, foreign_key: { to_table: :ledgers }, index: true
  end

end
