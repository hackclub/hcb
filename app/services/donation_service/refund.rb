# frozen_string_literal: true

module DonationService
  class Refund
    def initialize(donation_id:, amount:)
      @donation_id = donation_id
      @amount = amount
    end

    def run
      raise ArgumentError, "the donation must have settled" unless donation.canonical_transactions.any?
      raise ArgumentError, "the donation has already been refunded" if donation.refunded?

      ActiveRecord::Base.transaction do
        # 1. Mark refunded
        donation.mark_refunded!

        # 2. Un-front all pending transaction associated with this donation
        donation.canonical_pending_transactions.update_all(fronted: false)

        # 3. Waive all fees collected
        donation.canonical_transactions.each do |ct|
          fee = ct.fee
          fee.amount_cents_as_decimal = 0
          fee.reason = :donation_refunded
          fee.save!
        end

        # 4. Process remotely
        ::StripeService::Refund.create(payment_intent: payment_intent_id, amount: @amount)

        # 5. Create top-up on Stripe. Located in `StripeController#handle_charge_refunded`
      end
    end

    private

    def donation
      @donation ||= ::Donation.find(@donation_id)
    end

    def payment_intent_id
      donation.stripe_payment_intent_id
    end

  end
end
