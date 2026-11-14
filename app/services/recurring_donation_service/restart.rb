# frozen_string_literal: true

module RecurringDonationService
  # Stripe won't reactivate a canceled subscription, so restarting a recurring
  # donation copies it into a new one with a new subscription, billed to the
  # same Stripe customer and card. The first month is charged right away.
  class Restart
    class Error < StandardError; end

    def initialize(recurring_donation)
      @recurring_donation = recurring_donation
    end

    def run
      raise Error, "Only canceled donations can be restarted." unless @recurring_donation.canceled?

      # The lock stops a second restart from charging the donor again: it waits
      # here until the first one's donation exists, then finds it below.
      restarted, subscription = @recurring_donation.with_lock do
        existing = event.recurring_donations.where(email: @recurring_donation.email).where.not(stripe_status: [:canceled, :incomplete_expired]).first
        raise Error, "This donor already has a recurring donation to #{event.name} that's #{existing.stripe_status.humanize.downcase}." if existing

        restarted = event.recurring_donations.build(
          name: @recurring_donation.name(show_anonymous: true),
          email: @recurring_donation.email,
          amount: @recurring_donation.amount,
          anonymous: @recurring_donation.anonymous,
          fee_covered: @recurring_donation.fee_covered,
          tax_deductible: @recurring_donation.tax_deductible
        )
        restarted.validate!

        subscription = create_subscription(restarted.amount)
        restarted.sync_with_stripe_subscription!(subscription)
        restarted.save!

        [restarted, subscription]
      end

      # Paid only once the donation is saved, since `HandleInvoicePaid` drops
      # invoices for subscriptions it can't find.
      begin
        StripeService::Invoice.pay(subscription.latest_invoice.id, { off_session: true })
      rescue Stripe::CardError
        # Canceling an incomplete subscription expires it, which hides it the
        # same way as a donation form that was never paid.
        StripeService::Subscription.cancel(subscription.id)
        raise
      ensure
        restarted.sync_with_stripe_subscription!
        restarted.save!
      end

      restarted
    end

    private

    def event
      @recurring_donation.event
    end

    def create_subscription(amount)
      previous_subscription = @recurring_donation.stripe_subscription
      payment_method = previous_subscription.default_payment_method
      raise Error, "This donation doesn't have a saved card to charge." if payment_method.nil?

      price = StripeService::Price.create(
        currency: "usd",
        unit_amount: amount,
        recurring: { interval: "month" },
        product: previous_subscription.items.data.first.price.product
      )

      StripeService::Subscription.create(
        customer: previous_subscription.customer,
        items: [
          { price: price.id }
        ],
        default_payment_method: payment_method.id,
        payment_behavior: "default_incomplete",
        expand: ["latest_invoice.payment_intent", "default_payment_method"],
        metadata: { event_id: event.id, restarted_from_recurring_donation_id: @recurring_donation.id }
      )
    end

  end
end
