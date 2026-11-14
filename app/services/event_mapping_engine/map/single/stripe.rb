# frozen_string_literal: true

module EventMappingEngine
  module Map
    module Single
      class Stripe
        def initialize(canonical_transaction:)
          @canonical_transaction = canonical_transaction
        end

        def run
          return if @canonical_transaction.canonical_event_mapping.present?
          return unless @canonical_transaction.likely_stripe_card_transaction?

          @canonical_transaction.create_canonical_event_mapping!(
            event_id: @canonical_transaction.raw_stripe_transaction.likely_event_id,
            subledger_id: @canonical_transaction.stripe_card.subledger_id,
          )

          # A refund settles after the charge's pending transaction has, so
          # CanonicalPendingTransactionService::Settle never gives it a
          # category. Take the charge's instead.
          TransactionCategoryService
            .new(model: @canonical_transaction)
            .sync_from_card_charge!
        end

      end
    end
  end
end
