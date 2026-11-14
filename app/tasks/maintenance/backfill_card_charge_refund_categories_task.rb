# frozen_string_literal: true

module Maintenance
  # A refund settles onto a card charge after the charge's pending transaction
  # has, so CanonicalPendingTransactionService::Settle never gave it a category.
  # EventMappingEngine::Map::Single::Stripe now copies the charge's category
  # onto refunds as it maps them; this does the same for the ones it missed.
  class BackfillCardChargeRefundCategoriesTask < MaintenanceTasks::Task
    def collection
      CanonicalTransaction
        .where(transaction_source_type: RawStripeTransaction.name, transaction_source_id: RawStripeTransaction.refund.select(:id))
        .where.not(id: TransactionCategoryMapping.where(categorizable_type: "CanonicalTransaction").select(:categorizable_id))
    end

    def process(canonical_transaction)
      TransactionCategoryService
        .new(model: canonical_transaction)
        .sync_from_card_charge!
    end

  end
end
