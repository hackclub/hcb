# frozen_string_literal: true

module Maintenance
  # A refund, or a second capture, settles onto a card charge after the
  # charge's pending transaction has, so CanonicalPendingTransactionService::Settle
  # never gave it a category. EventMappingEngine::Map::Single::Stripe now
  # copies the charge's category onto such transactions as it maps them; this
  # does the same for the ones it missed.
  class BackfillCardChargeCategoriesTask < MaintenanceTasks::Task
    def collection
      CanonicalTransaction
        .where(ledger_item_id: Ledger::Item.where(linked_object_type: "CardCharge").select(:id))
        .where.not(id: TransactionCategoryMapping.where(categorizable_type: "CanonicalTransaction").select(:categorizable_id))
    end

    def process(canonical_transaction)
      TransactionCategoryService
        .new(model: canonical_transaction)
        .sync_from_card_charge!
    end

  end
end
