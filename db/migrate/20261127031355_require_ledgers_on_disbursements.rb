# frozen_string_literal: true

# Every disbursement records the ledgers it moves money between now that
# Maintenance::BackfillDisbursementLedgersTask has filled the old rows
# (https://github.com/hackclub/hcb/issues/14163), so both become required.
# Validating a check constraint first means setting NOT NULL doesn't hold a
# lock while it scans the table.
class RequireLedgersOnDisbursements < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  COLUMNS = %i[source_ledger_id destination_ledger_id].freeze

  def up
    COLUMNS.each do |column|
      name = "disbursements_#{column}_null"

      add_check_constraint(:disbursements, "#{column} IS NOT NULL", name:, validate: false)
      validate_check_constraint(:disbursements, name:)
      change_column_null :disbursements, column, false
      remove_check_constraint(:disbursements, name:)
    end
  end

  def down
    COLUMNS.each do |column|
      change_column_null :disbursements, column, true
    end
  end

end
