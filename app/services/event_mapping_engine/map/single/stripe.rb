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
          return unless @canonical_transaction.raw_stripe_transaction.likely_event_id

          @canonical_transaction.create_canonical_event_mapping!(
            event_id: @canonical_transaction.raw_stripe_transaction.likely_event_id,
            subledger_id: @canonical_transaction.stripe_card.subledger_id,
          )
        end

      end
    end
  end
end
