# frozen_string_literal: true

module OneTimeJobs
  class BackfillPaymentIntentEventIds < ApplicationJob
    def perform(dry_run: false)
      puts "dry run (no changes will be made)" if dry_run

      updated = 0
      failed  = 0

      no_event_id = []
      mismatched_event_id = []

      Stripe::PaymentIntent.where("created_at > '2024-01-01'").find_each do |intent|
        donation = Donation.find_by(payment_intent_id: intent.id)
        next unless donation

        if intent.metadata["event_id"].nil?
          no_event_id << intent.id
        elsif intent.metadata["event_id"] != donation.event_id.to_s
          mismatched_event_id << intent.id
        end

        begin
          unless dry_run
            Stripe::PaymentIntent.update(
              intent.id,
              { metadata: { event_id: donation.event_id } }
            )
          end
          puts "Updated #{intent.id} event_id to: #{donation.event_id}"
          updated += 1
        rescue Stripe::StripeError => e
          puts "ERROR #{intent.id}: #{e.message}"
          failed += 1
        end
      end

      puts "Updated: #{updated}, Failed: #{failed}"

      if no_event_id.any?
        puts "PaymentIntents with no event_id (#{no_event_id.size}):"
        puts no_event_id.join("\n")
      end

      if mismatched_event_id.any?
        puts "PaymentIntents with mismatched event_id (#{mismatched_event_id.size}):"
        puts mismatched_event_id.join("\n")
      end

    end
  end
end
