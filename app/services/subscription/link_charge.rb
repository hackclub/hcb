# frozen_string_literal: true

class Subscription
  # Links a new card charge to the active subscription it matches (merchant,
  # exact amount and timing). When nothing matches, looks for a new subscription
  # among the card's charges at that merchant (Subscription::Detect).
  #
  # Idempotent: a charge that's already linked is left alone. Called when an
  # authorization is approved (StripeAuthorizationService::CreateFromWebhook) and
  # when a charge settles (CanonicalEventMapping), which also covers force
  # captures that never had a pending transaction.
  class LinkCharge
    def self.on_canonical_transaction(canonical_transaction)
      ct = canonical_transaction
      return unless ct&.amount_cents&.negative? && ct.transaction_source_type == RawStripeTransaction.name

      hcb_code = ct.local_hcb_code
      new(hcb_code:).run if hcb_code
    end

    def initialize(hcb_code:, detect: true)
      @hcb_code = hcb_code
      @detect = detect
    end

    def run
      return if @hcb_code.subscription_id.present?
      return unless @hcb_code.card_charge?
      return if @hcb_code.pt&.declined?

      stripe_card = @hcb_code.stripe_card
      return unless stripe_card
      return unless @hcb_code.amount_cents.negative?

      merchant = @hcb_code.subscription_merchant
      return unless merchant

      subscription = stripe_card.subscriptions.active.find do |candidate|
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

      return unless @detect

      detected = Subscription::Detect.new(stripe_card:, merchant_network_id: merchant[:network_id], merchant_name: merchant[:name]).run
      detected.find { |detected_subscription| detected_subscription.hcb_codes.exists?(@hcb_code.id) }
    end

  end

end
