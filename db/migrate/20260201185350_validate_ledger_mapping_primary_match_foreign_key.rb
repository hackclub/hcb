# frozen_string_literal: true

class ValidateLedgerMappingPrimaryMatchForeignKey < ActiveRecord::Migration[8.0]
  def change
    # Step 3: Validate the foreign key constraint
    # This runs separately to avoid locking the table during constraint creation
    validate_foreign_key :ledger_mappings, name: "fk_ledger_mappings_primary_match"
  end
end
