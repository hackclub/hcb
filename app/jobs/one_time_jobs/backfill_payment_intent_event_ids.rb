# frozen_string_literal: true

module OneTimeJobs
  class BackfillPaymentIntentEventIds < ApplicationJob
    def perform(dry_run: false)
      puts "dry run (no changes will be made)" if dry_run

      updated = 0
      failed  = 0

      no_event_id = []
      mismatched_event_id = []

      Donation.where("created_at > '2024-01-01'").find_each do |donation|
        intent = Stripe::PaymentIntent.retrieve(donation.stripe_payment_intent_id)
        next unless intent

        if intent.metadata["event_id"].nil?
          no_event_id << intent.id
        elsif intent.metadata["event_id"] != donation.event_id.to_s
          mismatched_event_id << intent.id
        else
          next
        end

        begin
          unless dry_run
            Stripe::PaymentIntent.update(
              intent.id,
              { metadata: { event_id: donation.event_id } }
            )
          end
          puts "Updated #{intent.id} event_id from #{intent.metadata["event_id"].inspect} to: #{donation.event_id}"
          updated += 1
        rescue Stripe::StripeError => e
          puts "ERROR #{intent.id}: #{e.message}"
          failed += 1
        end
      end

      puts "Updated: #{updated}, Failed: #{failed}"

      if no_event_id.any?
        puts "PaymentIntents with no event_id (#{no_event_id.size}):"
        puts no_event_id.join(",")
      end

      if mismatched_event_id.any?
        puts "PaymentIntents with mismatched event_id (#{mismatched_event_id.size}):"
        puts mismatched_event_id.join(",")
      end

    end

  end
end
