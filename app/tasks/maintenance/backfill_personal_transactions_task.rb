# frozen_string_literal: true

module Maintenance
  # One-time backfill: migrates legacy HcbCode::PersonalTransaction records
  # (hcb_code_personal_transactions table, keyed by hcb_code_id) into the
  # root-level PersonalTransaction model, keyed by ledger_item_id instead.
  # Run once after deploying PersonalTransaction.
  class BackfillPersonalTransactionsTask < MaintenanceTasks::Task
    def collection
      HcbCode::PersonalTransaction.all
    end

    def process(personal_transaction)
      ledger_item = personal_transaction.hcb_code&.ledger_item
      raise "No ledger_item found for HcbCode::PersonalTransaction##{personal_transaction.id}" if ledger_item.nil?

      # Set every attribute up front (rather than letting callbacks run) so
      # this is a pure data copy: no re-sending of the reimbursement invoice.
      PersonalTransaction.find_or_create_by!(ledger_item:) do |pt|
        pt.invoice_id = personal_transaction.invoice_id
        pt.reporter_id = personal_transaction.reporter_id
        pt.created_at = personal_transaction.created_at
        pt.updated_at = personal_transaction.updated_at
      end
    end

  end
end
