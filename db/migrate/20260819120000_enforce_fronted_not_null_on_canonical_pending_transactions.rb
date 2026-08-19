# frozen_string_literal: true

class EnforceFrontedNotNullOnCanonicalPendingTransactions < ActiveRecord::Migration[8.1]
  def up
    # canonical_pending_transactions_fronted_null is already validated, so this
    # sets the column's real NOT NULL without a second full-table scan. Once
    # the column itself enforces it, the check constraint is redundant.
    change_column_null :canonical_pending_transactions, :fronted, false
    remove_check_constraint :canonical_pending_transactions, name: "canonical_pending_transactions_fronted_null"
  end

  def down
    change_column_null :canonical_pending_transactions, :fronted, true
  end

end
