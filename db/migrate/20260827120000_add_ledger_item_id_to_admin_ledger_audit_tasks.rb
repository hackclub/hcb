# frozen_string_literal: true

class AddLedgerItemIdToAdminLedgerAuditTasks < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_reference :admin_ledger_audit_tasks, :ledger_item, index: { algorithm: :concurrently }

    add_foreign_key :admin_ledger_audit_tasks, :ledger_items, validate: false

    validate_foreign_key :admin_ledger_audit_tasks, :ledger_items
  end

end
