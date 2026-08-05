# frozen_string_literal: true

module Maintenance
  # Cleans up CanonicalPendingTransactions that were settled to more than one
  # CanonicalTransaction. This happened for Stripe card charges that were
  # later refunded: the refund's CanonicalTransaction shares the same
  # `stripe_authorization_id` as the original charge, so the settle logic
  # (before it was fixed) would settle the CPT a second time, to the refund's
  # CT, instead of only ever settling to the original charge.
  #
  # For each affected CPT, this keeps the mapping to the one CanonicalTransaction
  # that isn't a Stripe refund (the original charge) and destroys the rest.
  # If a CPT doesn't have exactly one non-refund candidate, it's left alone
  # and reported so it can be looked at by hand.
  class DedupeCanonicalPendingSettledMappingsTask < MaintenanceTasks::Task
    class AnomalyError < StandardError; end

    def collection
      CanonicalPendingTransaction
        .stripe
        .where(id: duplicated_canonical_pending_transaction_ids)
    end

    def process(canonical_pending_transaction)
      mappings = canonical_pending_transaction.canonical_pending_settled_mappings.includes(canonical_transaction: :transaction_source)

      keepers, extras = mappings.partition { |mapping| !mapping.canonical_transaction.stripe_refund? }

      if keepers.size != 1
        Rails.error.unexpected(AnomalyError.new("CPT ##{canonical_pending_transaction.id} has #{mappings.size} settled mappings but #{keepers.size} non-refund candidates; skipping automatic cleanup."))
        return
      end

      extras.each(&:destroy!)
    end

    private

    def duplicated_canonical_pending_transaction_ids
      CanonicalPendingSettledMapping
        .group(:canonical_pending_transaction_id)
        .having("count(*) > 1")
        .select(:canonical_pending_transaction_id)
    end

  end
end
