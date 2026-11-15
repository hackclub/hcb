# frozen_string_literal: true

class Subscription
  # Given a settled card charge, links it to the subscription it pays for, or
  # creates a subscription when this charge and the earlier unlinked ones from
  # the same merchant form a cadence. See Subscription for what is covered.
  #
  # Idempotent: a charge that is already linked is left alone.
  class Detect
    MIN_CHARGES = 3
    # Three yearly charges would need over two years of history.
    MIN_YEARLY_CHARGES = 2
    # Closer together than this is a retry or a repeat purchase.
    MIN_GAP_DAYS = 5
    # A gap may span this many cycles (two skipped months, say).
    MAX_CYCLES = 3
    # Long enough to hold two yearly charges.
    LOOKBACK = 15.months

    def initialize(ledger_item)
      @item = ledger_item
    end

    def run
      return unless @item.subscription_candidate?

      @charge = @item.linked_object
      @ledger = @item.primary_ledger
      @rail = @charge&.stripe_card
      # shortcut: merchants without a Stripe network ID are skipped, key them by name if that turns out to be common
      @merchant_key = @charge&.merchant_network_id
      return if @ledger.nil? || @rail.nil? || @merchant_key.blank? || @charge.card_present?

      link_to_existing || create_from_history
    end

    private

    def link_to_existing
      amount_cents = @item.amount_cents.abs
      subscription = @ledger.subscriptions.where(merchant_key: @merchant_key).includes(:payment_rail)
                            .select { |s| s.due?(@item.datetime) && s.amount_fits?(amount_cents) && same_cardholder?(s.payment_rail) }
                            .min_by { |s| [s.payment_rail == @rail ? 0 : 1, (s.amount_cents - amount_cents).abs] }
      return unless subscription

      subscription.link!(@item, payment_rail: @rail)
      subscription
    end

    # Another card only counts when it is the same person's (a replaced or
    # swapped card). On a ledger where many people hold cards, someone else's
    # charge at the same merchant is their own subscription.
    def same_cardholder?(card)
      card == @rail || card.stripe_cardholder_id == @rail.stripe_cardholder_id
    end

    # Tries the charges of this exact amount first (a flat price), then every
    # charge from the merchant (usage billing), which has to fit more strictly.
    def create_from_history
      same_amount = without_repeats(history.select { |item| item.amount_cents == @item.amount_cents })
      create(same_amount, variable_amount: false) || create(history, variable_amount: true)
    end

    # This merchant's unlinked online charges on this card, up to this one.
    def history
      @history ||= Ledger::Item.settled
                               .joins(:primary_mapping).where(ledger_mappings: { ledger_id: @ledger.id })
                               .where(linked_object_type: CardCharge.name, linked_object_id: CardCharge.where(merchant_network_id: @merchant_key, stripe_card: @rail).select(:id))
                               .where(subscription_id: nil, amount_cents: ...0, datetime: (@item.datetime - LOOKBACK)..@item.datetime)
                               .includes(linked_object: :raw_pending_stripe_transaction)
                               .order(:datetime, :id)
                               .reject { |item| item.linked_object.card_present? }
    end

    def without_repeats(items)
      items.each_with_object([]) do |item, kept|
        kept << item if kept.empty? || days_between(kept.last, item) >= MIN_GAP_DAYS
      end
    end

    def days_between(a, b)
      (b.datetime - a.datetime) / 1.day
    end

    def create(items, variable_amount:)
      return if items.size < MIN_YEARLY_CHARGES

      cadence_days = fit_cadence(items.each_cons(2).map { |a, b| days_between(a, b) }, strict: variable_amount)
      return if cadence_days.nil?
      return if items.size < MIN_CHARGES && (variable_amount || cadence_days != 365)

      subscription = Subscription.new(
        ledger: @ledger,
        merchant_key: @merchant_key,
        name: YellowPages::Merchant.lookup(network_id: @merchant_key).name || @charge.merchant_data&.dig("name") || @merchant_key,
        variable_amount:,
        cadence_days:,
        next_expected_at: items.first.datetime
      )
      items.each do |item|
        subscription.record_charge(at: item.datetime, amount_cents: item.amount_cents.abs, payment_rail: item.linked_object.stripe_card || @rail)
      end

      Subscription.transaction do
        subscription.save!
        # Another job got to some of these charges first: leave them to it.
        linked = Ledger::Item.where(id: items.map(&:id), subscription_id: nil).update_all(subscription_id: subscription.id)
        raise ActiveRecord::Rollback if linked != items.size
      end

      subscription if subscription.persisted?
    end

    # The cycle length in days, or nil. The typical (median) gap has to be close
    # to a known cadence (31 days is monthly), and every gap within tolerance of
    # a whole number of cycles. Strict allows no skipped cycles.
    #
    # Only known cadences: on real data, free-form ones (every 43 days) were
    # almost all coincidences between unrelated purchases.
    def fit_cadence(gaps, strict:)
      typical = gaps.sort[(gaps.size - 1) / 2]
      days = Subscription::CADENCES.keys.find { |known| (typical - known).abs <= Subscription::TOLERANCE * known }
      return if days.nil?

      cycles = strict ? [1] : 1..MAX_CYCLES
      days if gaps.all? { |gap| cycles.any? { |k| (gap - (k * days)).abs <= Subscription::TOLERANCE * days } }
    end

  end

end
