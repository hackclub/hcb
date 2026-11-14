# frozen_string_literal: true

class Subscription
  #
  # Idempotent: a charge that's already linked is left alone.
  class LinkCharge
    def self.enqueue(ledger_item)
      Subscription::LinkChargeJob.perform_later(ledger_item) if candidate?(ledger_item) && ledger_item.primary_mapping.present?
    end

    def self.candidate?(ledger_item)
      ledger_item.linked_object_type == CardCharge.name &&
        ledger_item.settled? &&
        ledger_item.amount_cents.negative? &&
        ledger_item.subscription_id.nil?
    end

    def initialize(ledger_item:)
      @ledger_item = ledger_item
    end

    def run
      return unless self.class.candidate?(@ledger_item)

      card_charge = @ledger_item.linked_object
      stripe_card = card_charge.stripe_card
      return unless stripe_card

      merchant = @ledger_item.subscription_merchant
      return unless merchant

      # A settling charge's mapping commits several times, each enqueuing a
      # job. Locking the card serializes them, so only the first one links or
      # detects and the rest see the item already linked.
      stripe_card.with_lock do
        link_or_detect(stripe_card, merchant) if @ledger_item.reload.subscription_id.nil?
      end
    end

    private

    def link_or_detect(stripe_card, merchant)
      subscription = stripe_card.subscriptions.find do |candidate|
        candidate.matches?(
          merchant_network_id: merchant[:network_id],
          merchant_name: merchant[:name],
          amount_cents: @ledger_item.amount_cents,
          at: @ledger_item.datetime
        )
      end

      if subscription
        subscription.link!(@ledger_item)
        return subscription
      end

      detected = Subscription::Detect.new(stripe_card:, merchant_network_id: merchant[:network_id], merchant_name: merchant[:name]).run
      detected.find { |detected_subscription| detected_subscription.ledger_items.exists?(@ledger_item.id) }
    end

  end

end
