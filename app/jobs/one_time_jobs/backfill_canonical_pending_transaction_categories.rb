# frozen_string_literal: true

module OneTimeJobs
  class BackfillCanonicalPendingTransactionCategories
    include Sidekiq::IterableJob

    sidekiq_options(queue: :low, retry: false)

    def build_enumerator(cursor:)
      active_record_records_enumerator(CanonicalPendingTransaction, cursor:)
    end

    def each_iteration(canonical_pending_transaction)
      TransactionCategoryService.new(model: canonical_pending_transaction).sync_from_stripe!
    end

  end
end
