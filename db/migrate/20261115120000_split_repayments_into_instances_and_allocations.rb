# frozen_string_literal: true

class SplitRepaymentsIntoInstancesAndAllocations < ActiveRecord::Migration[8.1]
  # Stop application processes and workers for this migration: old code expects
  # repayments to contain expense rows, not repayment instances.
  def migrate(direction)
    safety_assured { super }
  end

  def up
    rename_table :repayments, :repayment_allocations
    create_table :repayments do |t|
      t.references :disbursement, null: false, foreign_key: true, index: { unique: true }
      t.timestamps
    end
    add_reference :repayment_allocations, :repayment, foreign_key: true

    execute <<~SQL
      INSERT INTO repayments (disbursement_id, created_at, updated_at)
      SELECT disbursement_id, MIN(created_at), MAX(updated_at)
      FROM repayment_allocations GROUP BY disbursement_id;

      UPDATE repayment_allocations SET repayment_id = repayments.id
      FROM repayments WHERE repayments.disbursement_id = repayment_allocations.disbursement_id;
    SQL

    change_column_null :repayment_allocations, :repayment_id, false
    remove_reference :repayment_allocations, :disbursement, foreign_key: true
    add_index :repayment_allocations, [:repayment_id, :ledger_item_id], unique: true
    add_check_constraint :repayment_allocations, "amount_cents > 0", name: "repayment_allocations_positive_amount"
  end

  def down
    remove_check_constraint :repayment_allocations, name: "repayment_allocations_positive_amount"
    remove_index :repayment_allocations, [:repayment_id, :ledger_item_id]
    add_reference :repayment_allocations, :disbursement, foreign_key: true
    execute <<~SQL
      UPDATE repayment_allocations SET disbursement_id = repayments.disbursement_id
      FROM repayments WHERE repayments.id = repayment_allocations.repayment_id;
    SQL
    change_column_null :repayment_allocations, :disbursement_id, false
    remove_reference :repayment_allocations, :repayment, foreign_key: true
    drop_table :repayments
    rename_table :repayment_allocations, :repayments
    add_index :repayments, [:disbursement_id, :ledger_item_id], unique: true
  end

end
