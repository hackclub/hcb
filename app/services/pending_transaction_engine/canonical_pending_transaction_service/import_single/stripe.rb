# frozen_string_literal: true

module PendingTransactionEngine
  module CanonicalPendingTransactionService
    module ImportSingle
      class Stripe
        def initialize(raw_pending_stripe_transaction:)
          @raw_pending_stripe_transaction = raw_pending_stripe_transaction
        end

        def run
          cpt = CanonicalPendingTransaction.find_or_initialize_by(raw_pending_stripe_transaction: @raw_pending_stripe_transaction)

          cpt.date = @raw_pending_stripe_transaction.date
          cpt.memo = @raw_pending_stripe_transaction.memo
          cpt.amount_cents = @raw_pending_stripe_transaction.amount_cents

          cpt.save!

          TransactionCategoryService
            .new(model: cpt)
            .sync_from_stripe!

          return cpt
        end

      end
    end
  end
end
