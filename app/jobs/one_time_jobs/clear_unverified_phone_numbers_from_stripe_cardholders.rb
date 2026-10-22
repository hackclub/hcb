# frozen_string_literal: true

module OneTimeJobs
  # Clears phone numbers from Stripe cardholders whose HCB user has not verified
  # their phone number. Intended to run once after deploying PR #13322, which
  # gates card issuance on phone_number_verified and stops syncing unverified
  # numbers to Stripe going forward.
  class ClearUnverifiedPhoneNumbersFromStripeCardholders < ApplicationJob
    def perform
      StripeCardholder
        .where.not(stripe_phone_number: [nil, ""])
        .joins(:user)
        .where(users: { phone_number_verified: [false, nil] })
        .find_each do |cardholder|
          next if cardholder.stripe_id.blank?

          cardholder.update!(stripe_phone_number: nil)
        rescue => e
          Rails.error.report(e)
        end
    end

  end
end
