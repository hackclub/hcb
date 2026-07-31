# frozen_string_literal: true

module Maintenance
  # Backfills CardCharge#stripe_card_id for charges created before the
  # association existed. CardCharge#stripe_card falls back to deriving the
  # card from raw transactions when stripe_card_id is nil, so this can run
  # at any time without breaking existing lookups.
  class BackfillCardChargeStripeCardsTask < MaintenanceTasks::Task
    def collection
      CardCharge.where(stripe_card_id: nil)
    end

    def process(card_charge)
      card_charge.update!(stripe_card_id: card_charge.stripe_card&.id)
    end

  end
end
