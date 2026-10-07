# frozen_string_literal: true

module Maintenance
  class BackfillExpensePayoutTransactionCategoriesTask < MaintenanceTasks::Task
    # Expense payouts used to settle without going through
    # CanonicalPendingTransactionService::Settle, so the category on the
    # pending transaction was never copied to the settled one.
    def collection
      CanonicalPendingSettledMapping
        .where(canonical_pending_transaction_id: CanonicalPendingTransaction.reimbursement_expense_payout.select(:id))
        .where(canonical_pending_transaction_id: TransactionCategoryMapping.where(categorizable_type: "CanonicalPendingTransaction").select(:categorizable_id))
        .where.not(canonical_transaction_id: TransactionCategoryMapping.where(categorizable_type: "CanonicalTransaction").select(:categorizable_id))
    end

    def process(settled_mapping)
      canonical_transaction = settled_mapping.canonical_transaction
      return if canonical_transaction.category_mapping.present?

      pending_mapping = settled_mapping.canonical_pending_transaction.category_mapping

      canonical_transaction.create_category_mapping!(
        category: pending_mapping.category,
        assignment_strategy: pending_mapping.assignment_strategy,
      )
    end

  end
end
