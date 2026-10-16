# frozen_string_literal: true

module Maintenance
  # Backfills subscriptions from existing charges on every active card.
  # Re-running is safe: charges already linked are skipped and duplicate
  # subscriptions are never created.
  class DetectSubscriptionsTask < MaintenanceTasks::Task
    def collection
      StripeCard.active
    end

    def process(stripe_card)
      Subscription::Detect.new(stripe_card:).run
    end

  end
end
