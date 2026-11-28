# frozen_string_literal: true

# Every disbursement records the ledgers it moves money between now that
# Maintenance::BackfillDisbursementLedgersTask has filled the old rows
# (https://github.com/hackclub/hcb/issues/14163), so both become required.
# Validating a check constraint first means setting NOT NULL doesn't hold a
# lock while it scans the table.
class RequireLedgersOnDisbursements < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_check_constraint :disbursements, "source_ledger_id IS NOT NULL", name: "disbursements_source_ledger_id_null", validate: false
    validate_check_constraint :disbursements, name: "disbursements_source_ledger_id_null"
    change_column_null :disbursements, :source_ledger_id, false
    remove_check_constraint :disbursements, name: "disbursements_source_ledger_id_null"

    add_check_constraint :disbursements, "destination_ledger_id IS NOT NULL", name: "disbursements_destination_ledger_id_null", validate: false
    validate_check_constraint :disbursements, name: "disbursements_destination_ledger_id_null"
    change_column_null :disbursements, :destination_ledger_id, false
    remove_check_constraint :disbursements, name: "disbursements_destination_ledger_id_null"
  end

  # rubocop:disable Rails/BulkChangeTable -- each statement commits on its own (see disable_ddl_transaction!)
  def down
    change_column_null :disbursements, :source_ledger_id, true
    change_column_null :disbursements, :destination_ledger_id, true
  end
  # rubocop:enable Rails/BulkChangeTable

end
