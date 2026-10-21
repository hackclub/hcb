# frozen_string_literal: true

class Subscription
  # Links a settled card charge to the subscription it matches (merchant, exact
  # amount and timing). When nothing matches, looks for a new subscription among
  # the card's charges at that merchant (Subscription::Detect).
  #
  # Idempotent: a charge that's already linked is left alone.
  class LinkCharge
    def initialize(hcb_code:)
      @hcb_code = hcb_code
    end

    def run
      return if @hcb_code.subscription_id.present?
      return unless @hcb_code.card_charge?
      return unless @hcb_code.amount_cents.negative?

      stripe_card = @hcb_code.stripe_card
      return unless stripe_card

      merchant = @hcb_code.subscription_merchant
      return unless merchant

      subscription = stripe_card.subscriptions.find do |candidate|
        candidate.matches?(
          merchant_network_id: merchant[:network_id],
          merchant_name: merchant[:name],
          amount_cents: @hcb_code.amount_cents,
          at: @hcb_code.datetime
        )
      end

      if subscription
        subscription.link!(@hcb_code)
        return subscription
      end

      detected = Subscription::Detect.new(stripe_card:, merchant_network_id: merchant[:network_id], merchant_name: merchant[:name]).run
      detected.find { |detected_subscription| detected_subscription.hcb_codes.exists?(@hcb_code.id) }
    end

  end

end
