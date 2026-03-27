# frozen_string_literal: true

module OneTimeJobs
  class BackfillPaymentIntentEventIds < ApplicationJob
    sidekiq_options retry: false

    def perform(dry_run: false)
      puts "dry run (no changes will be made)" if dry_run

      donations = Donation.where("created_at > '2024-01-01'").where.not(stripe_payment_intent_id: nil)
      pi_ids_needed = donations.pluck(:stripe_payment_intent_id).to_set
      puts "Found #{pi_ids_needed.size} donations with payment intent IDs"

      # Bulk-fetch payment intents via list API (~1,850 requests instead of ~185k)
      puts "Fetching payment intents from Stripe..."
      pi_metadata = {} # pi_id => event_id from metadata (or nil)
      fetched = 0

      Stripe::PaymentIntent.list(
        created: { gte: Time.parse("2024-01-01").to_i },
        limit: 100
      ).auto_paging_each do |intent|
        fetched += 1
        pi_metadata[intent.id] = intent.metadata["event_id"] if pi_ids_needed.include?(intent.id)
        puts "Fetched #{fetched} payment intents (#{pi_metadata.size} matched)..." if fetched % 10_000 == 0
      end

      puts "Fetched #{fetched} total from Stripe, #{pi_metadata.size} matched donations"

      updated = 0
      failed = 0
      not_found = 0
      no_event_id = []
      mismatched_event_id = []

      donations.find_each do |donation|
        pi_id = donation.stripe_payment_intent_id

        unless pi_metadata.key?(pi_id)
          not_found += 1
          next
        end

        current_event_id = pi_metadata[pi_id]

        if current_event_id.nil?
          no_event_id << pi_id
        elsif current_event_id != donation.event_id.to_s
          mismatched_event_id << pi_id
        else
          next
        end

        begin
          unless dry_run
            Stripe::PaymentIntent.update(pi_id, metadata: { event_id: donation.event_id })
          end
          puts "Updated #{pi_id} event_id from #{current_event_id.inspect} to: #{donation.event_id}"
          updated += 1
        rescue Stripe::StripeError => e
          puts "ERROR #{pi_id}: #{e.message}"
          failed += 1
        end
      end

      puts "Updated: #{updated}, Failed: #{failed}, Not found in Stripe: #{not_found}"

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
