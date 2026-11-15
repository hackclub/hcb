# frozen_string_literal: true

class Subscription
  # Given a settled card charge, links it to the subscription it pays for, or
  # creates a subscription when this charge and the earlier unlinked ones from
  # the same merchant form a cadence. See Subscription for what is covered.
  #
  # Idempotent: a charge that is already linked is left alone.
  class Detect
    MIN_CHARGES = 3
    MIN_YEARLY_CHARGES = 2
    # A gap may span this many cycles (two skipped months, say).
    MAX_CYCLES = 3
    # How far a charge may be from a whole cycle to start a subscription, as a
    # fraction. Tighter than Subscription::TOLERANCE, which is for charges
    # joining one: at 20%, real data had chains forming among frequent purchases
    # of one price. Only known cadences are tried for the same reason: free-form
    # ones (every 43 days) were almost all coincidences.
    CHAIN_TOLERANCE = 0.1
    # The card is a signal, not a requirement. Charges on someone else's card
    # can still form or join a subscription, but need stronger evidence: this
    # many charges, the exact amount, and no early or skipped cycles.
    MIN_OTHER_CARD_CHARGES = 4
    OTHER_CARD_EARLY = 1.day
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
                            .select { |s| same_cardholder?(s.payment_rail) ? s.due?(@item.datetime) && s.amount_fits?(amount_cents) : exact_match?(s, amount_cents) }
                            .min_by { |s| [s.payment_rail == @rail ? 0 : 1, (s.amount_cents - amount_cents).abs] }
      return unless subscription

      subscription.link!(@item, payment_rail: @rail)
      subscription
    end

    # A replaced card belongs to the same cardholder, so it counts as the same
    # card. On a ledger where many people hold cards, someone else's charge at
    # the same merchant is usually their own subscription.
    def same_cardholder?(card)
      card == @rail || card.stripe_cardholder_id == @rail.stripe_cardholder_id
    end

    def exact_match?(subscription, amount_cents)
      !subscription.variable_amount? && subscription.amount_cents == amount_cents &&
        @item.datetime >= subscription.next_expected_at - OTHER_CARD_EARLY
    end

    # Tries, in order: this cardholder's charges of this exact amount (a flat
    # price), all of this cardholder's charges (usage billing), then charges of
    # this exact amount on any card.
    def create_from_history
      mine = history.select { |item| same_cardholder?(item.linked_object.stripe_card) }

      flat(same_amount(mine), max_cycles: MAX_CYCLES, min_charges: MIN_CHARGES) ||
        variable(mine) ||
        flat(same_amount(history), max_cycles: 1, min_charges: MIN_OTHER_CARD_CHARGES)
    end

    def same_amount(items)
      items.select { |item| item.amount_cents == @item.amount_cents }
    end

    # This merchant's unlinked online charges on the ledger, up to this one.
    def history
      @history ||= Ledger::Item.settled
                               .joins(:primary_mapping).where(ledger_mappings: { ledger_id: @ledger.id })
                               .where(linked_object_type: CardCharge.name, linked_object_id: CardCharge.where(merchant_network_id: @merchant_key).select(:id))
                               .where(subscription_id: nil, amount_cents: ...0, datetime: (@item.datetime - LOOKBACK)..@item.datetime)
                               .includes(linked_object: [:raw_pending_stripe_transaction, :stripe_card])
                               .order(:datetime, :id)
                               .reject { |item| item.linked_object.card_present? }
    end

    # A flat price: the longest chain of same-amount charges ending at this one.
    # A chain that skips a cycle at most steps is really a longer cadence, and
    # between equally long chains the one that skips fewest wins, so a monthly
    # charge isn't read as biweekly with gaps.
    def flat(items, max_cycles:, min_charges:)
      cadence_days, (chain, _skips) = Subscription::CADENCES.keys
                                                            .map { |days| [days, chain(items, days, max_cycles)] }
                                                            .reject { |_days, (chain, skips)| skips * 2 > chain.size - 1 }
                                                            .max_by { |_days, (chain, skips)| [chain.size, -skips] }
      return if chain.nil?

      # Three yearly charges would need over two years of history.
      min_charges = MIN_YEARLY_CHARGES if cadence_days == 365 && max_cycles > 1

      create(chain, variable_amount: false, cadence_days:) if chain.size >= min_charges
    end

    # Walks back from this charge one cycle at a time, taking the charge closest
    # to each step and skipping up to max_cycles - 1 cycles. Walking a chain,
    # rather than requiring every charge to fit, finds a subscription among
    # one-off purchases, retries, and a second subscription at the same price.
    def chain(items, cadence_days, max_cycles)
      chain = [@item]
      skips = 0

      loop do
        earlier = items.select { |item| item.datetime < chain.first.datetime }
        step, previous = (1..max_cycles).filter_map do |k|
          closest = earlier.min_by { |item| off_by(item, chain.first, k * cadence_days) }
          [k, closest] if closest && off_by(closest, chain.first, k * cadence_days) <= CHAIN_TOLERANCE * cadence_days
        end.first
        return [chain, skips] if previous.nil?

        skips += 1 if step > 1
        chain.unshift(previous)
      end
    end

    def off_by(earlier, later, days)
      (days_between(earlier, later) - days).abs
    end

    # Usage billing: every charge from the merchant, each gap exactly one cycle
    # of the same known cadence.
    def variable(items)
      return if items.size < MIN_CHARGES

      gaps = items.each_cons(2).map { |a, b| days_between(a, b) }
      cadence_days = Subscription::CADENCES.keys.find do |days|
        gaps.all? { |gap| (gap - days).abs <= Subscription::TOLERANCE * days }
      end

      create(items, variable_amount: true, cadence_days:) if cadence_days
    end

    def days_between(a, b)
      (b.datetime - a.datetime) / 1.day
    end

    def create(items, variable_amount:, cadence_days:)
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

      subscription.tap(&:score!) if subscription.persisted?
    end

  end

end
