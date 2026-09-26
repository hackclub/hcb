# frozen_string_literal: true

module Maintenance
  # Physical cards issued before Stripe introduced personalization designs
  # (~2024-03-26) have no personalization design on Stripe. StripeCard#sync_from_stripe!
  # falls back to the default black design for them at sync time; this persists
  # that default so the fallback can be removed. Safe to re-run; only fills
  # cards with no design.
  class BackfillLegacyStripeCardPersonalizationDesignsTask < MaintenanceTasks::Task
    def collection
      StripeCard.physical
                .where(stripe_card_personalization_design_id: nil)
                .where(created_at: ...Time.utc(2024, 3, 27))
    end

    def process(card)
      card.update_column(:stripe_card_personalization_design_id, StripeCard::PersonalizationDesign.default.id)
    end

  end
end
