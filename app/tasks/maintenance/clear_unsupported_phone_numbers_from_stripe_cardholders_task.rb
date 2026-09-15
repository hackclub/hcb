# frozen_string_literal: true

module Maintenance
  # removes phone numbers for country codes that are not in SMS_SUPPORTED on Stripe's end for existing users
  class ClearUnsupportedPhoneNumbersFromStripeCardholdersTask < MaintenanceTasks::Task
    def collection
      StripeCardholder
        .where.not(stripe_phone_number: [nil, ""])
        .where.not(stripe_id: [nil, ""])
    end

    def process(cardholder)
      return if StripeCardholder.phone_number_supported?(cardholder.stripe_phone_number)

      cardholder.update!(stripe_phone_number: nil)
    rescue => e
      Rails.error.report(e, context: { stripe_cardholder_id: cardholder.id })
    end

  end
end
