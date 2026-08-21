# frozen_string_literal: true

module Maintenance
  # FeeReimbursementService::Nightly's backstop used to create a
  # CanonicalPendingTransaction for any processed-but-CPT-less fee
  # reimbursement without checking whether its top-up had already settled as
  # a real CanonicalTransaction. For old reimbursements whose money already
  # moved and reconciled, the backfilled CPT's week-based hcb_code can land on
  # a *different* HcbCode/Ledger::Item than the one the real settled
  # transaction lives on (bank/ACH clearing routinely crosses an ISO week
  # boundary) — producing an orphaned, permanently-unmapped, never-settling
  # duplicate. See FeeReimbursement#settled_fee_reimbursement_transaction.
  #
  # FeeReimbursementService::CreateCanonicalPendingTransaction now checks for
  # this before creating anything — this task removes what the bug already
  # created before that fix shipped.
  #
  # Only removes the CPT chain (raw pending transaction, category mapping,
  # event mapping, CPT) and the Ledger::Item/Ledger::Mapping it lives on, and
  # only when that item is left completely empty afterward — if anything else
  # (a settled CT, a comment, a receipt) is attached, the item is left alone
  # rather than guessing. Safe to rerun: once a reimbursement's erroneous CPT
  # is gone, it drops out of the collection.
  class DeleteOrphanedFeeReimbursementCptsTask < MaintenanceTasks::Task
    def collection
      FeeReimbursement.where.associated(:raw_pending_fee_reimbursement_transaction)
    end

    def process(fee_reimbursement)
      return unless fee_reimbursement.settled_fee_reimbursement_transaction.present?

      rpfrt = fee_reimbursement.raw_pending_fee_reimbursement_transaction
      cpt = rpfrt&.canonical_pending_transaction
      return unless cpt

      ledger_item_id = cpt.ledger_item_id

      # Destroying the CPT and its ledger item in the same transaction would
      # trip CanonicalPendingTransaction's own after_commit (it fires on
      # destroy too, unconditioned on create/update): it calls
      # ledger_item.map!/.refresh! once this transaction commits, which
      # reloads the ledger item — raising RecordNotFound if that row is
      # *also* already gone by then. Commit the CPT/rpfrt removal first (that
      # callback runs safely against a still-existing, now-childless ledger
      # item) and only then decide whether to remove the ledger item itself.
      ActiveRecord::Base.transaction do
        TransactionCategoryMapping.where(categorizable: cpt).delete_all
        CanonicalPendingEventMapping.where(canonical_pending_transaction: cpt).delete_all
        cpt.destroy!
        rpfrt.destroy!
      end

      destroy_if_empty(Ledger::Item.find_by(id: ledger_item_id)) if ledger_item_id
    end

    private

    def destroy_if_empty(ledger_item)
      return unless ledger_item

      ledger_item.reload
      return if ledger_item.canonical_transactions.any?
      return if ledger_item.canonical_pending_transactions.any?
      return if ledger_item.comments.any?
      return if ledger_item.receipts.any?

      ActiveRecord::Base.transaction do
        Ledger::Mapping.where(ledger_item:).delete_all
        ledger_item.destroy!
      end
    end

  end
end
