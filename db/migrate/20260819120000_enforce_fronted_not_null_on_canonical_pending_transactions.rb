# frozen_string_literal: true

class EnforceFrontedNotNullOnCanonicalPendingTransactions < ActiveRecord::Migration[8.1]
  def up
    change_column_null :canonical_pending_transactions, :fronted, false
    remove_check_constraint :canonical_pending_transactions, name: "canonical_pending_transactions_fronted_null"
  end

  def down
    add_check_constraint :canonical_pending_transactions, "fronted IS NOT NULL", name: "canonical_pending_transactions_fronted_null", validate: false
    validate_check_constraint :canonical_pending_transactions, name: "canonical_pending_transactions_fronted_null"
    change_column_null :canonical_pending_transactions, :fronted, true
  end

end
