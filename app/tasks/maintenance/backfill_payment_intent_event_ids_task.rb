# frozen_string_literal: true

module Maintenance
  class BackfillPaymentIntentEventIdsTask < MaintenanceTasks::Task
    # Backfills missing or mismatched `event_id` metadata on Stripe
    # PaymentIntents for donations created after 2026-03-25.
    def collection
      Donation.where("created_at > '2026-03-25'").where.not(stripe_payment_intent_id: nil)
    end

    def process(donation)
      pi_id = donation.stripe_payment_intent_id
      intent = Stripe::PaymentIntent.retrieve(pi_id)
      current_event_id = intent.metadata["event_id"]

      return if current_event_id == donation.event_id.to_s

      Stripe::PaymentIntent.update(pi_id, metadata: { event_id: donation.event_id })
    end

  end
end
