# frozen_string_literal: true

module CanonicalPendingTransactionService
  class Unsettle
    def initialize(canonical_pending_transaction:)
      @canonical_pending_transaction = canonical_pending_transaction
    end

    def run
      return unless settled?

      ActiveRecord::Base.transaction do
        canonical_pending_settled_mappings.destroy_all

        ach_transfer.mark_in_transit! if ach_transfer&.deposited? # only change deposited. otherwise already in rejected state or in_transit
      end
    end

    private

    def ach_transfer
      raw_pending_outgoing_ach_transaction.try(:ach_transfer)
    end

    def raw_pending_outgoing_ach_transaction
      @canonical_pending_transaction.raw_pending_outgoing_ach_transaction
    end

    def canonical_pending_settled_mappings
      @canonical_pending_transaction.canonical_pending_settled_mappings
    end

    def settled?
      @canonical_pending_transaction.settled?
    end

  end
end
