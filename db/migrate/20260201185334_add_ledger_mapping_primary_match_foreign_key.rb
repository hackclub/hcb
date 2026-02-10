# frozen_string_literal: true

class AddLedgerMappingPrimaryMatchForeignKey < ActiveRecord::Migration[8.0]
  def change
    # Step 2: Add composite foreign key to enforce on_primary_ledger matches ledger.primary
    # Using validate: false for non-blocking addition (validated in separate migration)
    add_foreign_key :ledger_mappings, :ledgers,
                    column: [:ledger_id, :on_primary_ledger],
                    primary_key: [:id, :primary],
                    name: "fk_ledger_mappings_primary_match",
                    validate: false
  end
end
