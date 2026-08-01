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
      card_charge.set_stripe_card
      card_charge.save!
    end

  end
end
