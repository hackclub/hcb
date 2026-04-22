# frozen_string_literal: true

module OneTimeJobs
  class ClearUnverifiedPhoneNumbersFromStripe < ApplicationJob
    sidekiq_options retry: false

    def perform(dry_run: true)
      puts "Dry run — no changes will be made" if dry_run

      scope = StripeCardholder
        .where.not(stripe_phone_number: [nil, ""])
        .where.not(stripe_id: [nil, ""])
        .joins(:user)
        .where(users: { phone_number_verified: false })

      puts "Found #{scope.count} cardholder(s) with unverified phone numbers in Stripe"

      cleared = 0
      failed = 0

      scope.find_each do |cardholder|
        if dry_run
          puts "[DRY RUN] Would clear phone for cardholder #{cardholder.id} (user #{cardholder.user_id})"
          next
        end

        cardholder.update!(stripe_phone_number: nil)
        puts "Cleared phone for cardholder #{cardholder.id} (user #{cardholder.user_id})"
        cleared += 1
      rescue => e
        puts "Failed for cardholder #{cardholder.id}: #{e.message}"
        failed += 1
      end

      puts "Done. Cleared: #{cleared}, Failed: #{failed}" unless dry_run
    end

  end
end
