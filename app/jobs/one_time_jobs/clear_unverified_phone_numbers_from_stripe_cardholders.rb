# frozen_string_literal: true

module OneTimeJobs
  class ClearUnverifiedPhoneNumbersFromStripeCardholders < ApplicationJob
    def perform
      cardholders = StripeCardholder
        .where.not(stripe_phone_number: [nil, ""])
        .where.not(stripe_id: nil)
        .joins(:user)
        .where(users: { phone_number_verified: false })

      puts "Clearing phone numbers from #{cardholders.count} Stripe cardholders with unverified phone numbers"

      success = 0
      errors  = 0

      cardholders.find_each do |cardholder|
        cardholder.update!(stripe_phone_number: nil)
        success += 1
      rescue => e
        errors += 1
        puts "ERROR: StripeCardholder##{cardholder.id} — #{e.class}: #{e.message}"
      end

      puts "Done: #{success} cleared, #{errors} errors"
    end
  end
end
