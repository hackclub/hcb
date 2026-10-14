# frozen_string_literal: true

module Maintenance
  # Backfills subscriptions from existing charges on every active card whose
  # organization has subscriptions enabled. Run after enabling the flag for an
  # organization; re-running is safe (charges already linked are skipped and
  # duplicate subscriptions are never created). Organizations enabled through a
  # percentage gate aren't picked up; enable them individually first.
  class DetectSubscriptionsTask < MaintenanceTasks::Task
    def collection
      feature = Flipper[Subscription::FLAG]
      return StripeCard.active if feature.boolean_value

      event_ids = feature.actors_value.filter_map do |flipper_id|
        flipper_id.delete_prefix("#{Event.name};").to_i if flipper_id.start_with?("#{Event.name};")
      end

      StripeCard.active.where(event_id: event_ids)
    end

    def process(stripe_card)
      Subscription::Detect.new(stripe_card:).run
    end

  end
end
