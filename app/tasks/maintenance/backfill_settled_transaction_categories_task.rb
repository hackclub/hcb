# frozen_string_literal: true

module Maintenance
  class BackfillSettledTransactionCategoriesTask < MaintenanceTasks::Task
    # These types used to settle without going through
    # CanonicalPendingTransactionService::Settle, so the category on the
    # pending transaction was never copied to the settled one.
    def collection
      CanonicalTransaction
        .where(id: settled_from_affected_pending_transactions.select(:canonical_transaction_id))
        .or(CanonicalTransaction.where(hcb_code: categorized_payout_pending_transactions.select(:hcb_code)))
        .where.not(id: TransactionCategoryMapping.where(categorizable_type: "CanonicalTransaction").select(:categorizable_id))
    end

    def process(canonical_transaction)
      return if canonical_transaction.category_mapping.present?

      pending_transaction = canonical_transaction.canonical_pending_transaction ||
                            CanonicalPendingTransaction.find_by(hcb_code: canonical_transaction.hcb_code)
      pending_mapping = pending_transaction&.category_mapping
      return unless pending_mapping

      canonical_transaction.create_category_mapping!(
        category: pending_mapping.category,
        assignment_strategy: pending_mapping.assignment_strategy,
      )
    end

    private

    def settled_from_affected_pending_transactions
      CanonicalPendingSettledMapping.where(canonical_pending_transaction_id: categorized(affected_pending_transactions).select(:id))
    end

    # Reversed payouts come back as a second transaction on the same HCB code
    # (see EventMappingEngine::Map::HcbCodes::Short), so match those by code.
    def categorized_payout_pending_transactions
      categorized(
        CanonicalPendingTransaction.reimbursement_expense_payout
                                   .or(CanonicalPendingTransaction.reimbursement_payout_holding)
      )
    end

    def affected_pending_transactions
      CanonicalPendingTransaction.increase_check
                                 .or(CanonicalPendingTransaction.wire)
                                 .or(CanonicalPendingTransaction.check_deposit)
                                 .or(CanonicalPendingTransaction.stripe_service_fee)
                                 .or(CanonicalPendingTransaction.fee_revenue)
                                 .or(CanonicalPendingTransaction.reimbursement_expense_payout)
                                 .or(CanonicalPendingTransaction.reimbursement_payout_holding)
    end

    def categorized(pending_transactions)
      pending_transactions.where(id: TransactionCategoryMapping.where(categorizable_type: "CanonicalPendingTransaction").select(:categorizable_id))
    end

  end
end
