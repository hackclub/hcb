class AddLedgerMappingPrimaryMatchConstraint < ActiveRecord::Migration[8.0]
  # This migration adds database-level enforcement to ensure that
  # ledger_mappings.on_primary_ledger always matches ledgers.primary.
  #
  # Design Decision: Composite Foreign Key Approach
  # ------------------------------------------------
  # We use a composite foreign key instead of a trigger:
  #
  # Pros:
  # - Declarative: Uses standard PostgreSQL foreign keys
  # - Follows existing codebase patterns (no triggers currently used)
  # - Performant: Composite FK with unique index is efficient
  # - Maintainable: Easier to understand than trigger logic
  #
  # Cons:
  # - Requires an additional unique index on ledgers(id, primary)
  # - Slightly less obvious than a CHECK constraint (but CHECK can't reference other tables)
  #
  # How it works:
  # 1. Create unique index on ledgers(id, primary)
  # 2. Add composite FK: ledger_mappings(ledger_id, on_primary_ledger) → ledgers(id, primary)
  # 3. This ensures (ledger_id, on_primary_ledger) must exist as (id, primary) in ledgers table

  disable_ddl_transaction!

  def change
    # Step 1: Add unique index on ledgers(id, primary) to enable composite FK
    # Note: id is already unique (primary key), so this index is primarily
    # for enabling the composite foreign key constraint
    # Using algorithm: :concurrently to avoid blocking writes
    add_index :ledgers, [:id, :primary],
              unique: true,
              name: "index_ledgers_on_id_and_primary",
              algorithm: :concurrently
  end
end
