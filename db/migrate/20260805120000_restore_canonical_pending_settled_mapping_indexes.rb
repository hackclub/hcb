# frozen_string_literal: true

# A CanonicalPendingTransaction can settle into more than one
# CanonicalTransaction (a Stripe authorization may be captured several times),
# so canonical_pending_transaction_id is not unique. This restores the
# non-unique indexes on databases where an attempt to make them unique
# partially applied, and is a no-op on databases that already match
# db/schema.rb.
class RestoreCanonicalPendingSettledMappingIndexes < ActiveRecord::Migration[8.1]
  TABLE = :canonical_pending_settled_mappings

  disable_ddl_transaction!

  def up
    restore :canonical_pending_transaction_id,
            as: "index_canonical_pending_settled_map_on_canonical_pending_tx_id",
            replacing: "index_cpsm_on_cpt_id"

    restore :canonical_transaction_id,
            as: "index_canonical_pending_settled_mappings_on_canonical_tx_id",
            replacing: "index_cpsm_on_ct_id"
  end

  def down
    # Nothing to undo. This migration only converges a database onto the
    # indexes db/schema.rb already declares, so the state it produces is also
    # the state that precedes it.
  end

  private

  def restore(column, as:, replacing:)
    # `if_not_exists` compiles to `CREATE INDEX IF NOT EXISTS`, which matches on
    # name alone, so on its own it would skip over an invalid index left behind
    # by a cancelled concurrent build.
    stale = index(as)
    drop(as) if stale && !matches?(stale, column)

    # Add before dropping what it replaces, so the column is never unindexed.
    add_index TABLE, column, name: as, if_not_exists: true, algorithm: :concurrently
    drop(replacing)

    verify!(column, as:)
  end

  def drop(name)
    remove_index TABLE, name:, if_exists: true, algorithm: :concurrently
  end

  def verify!(column, as:)
    restored = index(as)

    raise "#{as} is missing" if restored.nil?
    raise "#{as} is not a valid, non-unique index on #{TABLE}.#{column}" unless matches?(restored, column)
  end

  def index(name)
    connection.indexes(TABLE).find { |index| index.name == name }
  end

  def matches?(index, column)
    index.valid && !index.unique && index.columns == [column.to_s]
  end

end
