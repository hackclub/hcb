# frozen_string_literal: true

class Subscription
  # Finds flat-amount subscriptions among a card's settled charges and creates
  # them (source: charges). A subscription is one merchant charging the exact
  # same amount at least MIN_CHARGES times, with the typical gap close to one of
  # the cadence buckets (or a free-form number of days) and every gap within
  # ±20% of one to three cycles.
  #
  # Linking is retroactive: every charge but the earliest stops needing a
  # receipt, which can unlock a card on the next card-locking recompute.
  class Detect
    MIN_CHARGES = 3
    MIN_GAP_DAYS = 5
    LOOKBACK = 13.months

    def initialize(stripe_card:, merchant_network_id: nil, merchant_name: nil)
      @stripe_card = stripe_card
      @merchant_network_id = merchant_network_id.presence
      @merchant_name = merchant_name.presence
      @merchant_key = Subscription.merchant_key(network_id: merchant_network_id, name: merchant_name)
    end

    # Returns the subscriptions it created.
    def run
      return [] unless @stripe_card.stripe_id.present? && Subscription.enabled_for?(@stripe_card.event)

      charges.group_by { |charge| [charge[:merchant_key], charge[:amount_cents]] }.filter_map do |_key, group|
        next if group.size < MIN_CHARGES

        create_from(group.sort_by { |charge| [charge[:charged_at], charge[:hcb_code].id] })
      end
    end

    private

    def charges
      hcb_code_strings = settled_charges.distinct.pluck(:hcb_code)

      HcbCode.where(hcb_code: hcb_code_strings, subscription_id: nil).filter_map do |hcb_code|
        next unless hcb_code.card_charge?
        next unless hcb_code.amount_cents.negative?

        merchant = hcb_code.subscription_merchant
        next unless merchant

        merchant_key = Subscription.merchant_key(network_id: merchant[:network_id], name: merchant[:name])
        next if merchant_key.nil?
        next if @merchant_key && merchant_key != @merchant_key

        {
          hcb_code:,
          merchant:,
          merchant_key:,
          amount_cents: hcb_code.amount_cents.abs,
          charged_at: hcb_code.datetime || hcb_code.created_at,
        }
      end
    end

    # Narrowed to one merchant in SQL when asked for one, so a new charge only
    # loads that merchant's history rather than every charge on the card.
    def settled_charges
      scope = CanonicalTransaction.stripe_transaction
                                  .where("raw_stripe_transactions.stripe_transaction->>'card' = ?", @stripe_card.stripe_id)
                                  .where("canonical_transactions.amount_cents < 0")
                                  .where("canonical_transactions.date >= ?", LOOKBACK.ago.to_date)

      if @merchant_network_id
        scope.where("raw_stripe_transactions.stripe_transaction->'merchant_data'->>'network_id' = ?", @merchant_network_id)
      elsif @merchant_name
        scope.where("LOWER(TRIM(raw_stripe_transactions.stripe_transaction->'merchant_data'->>'name')) = ?", @merchant_name.strip.downcase)
      else
        scope
      end
    end

    def create_from(group)
      gaps = group.each_cons(2).map { |a, b| (b[:charged_at] - a[:charged_at]) / 1.day }
      return if gaps.any? { |gap| gap < MIN_GAP_DAYS }

      cadence, cadence_days = fit_cadence(gaps)
      return if cadence.nil?

      merchant = group.last[:merchant]
      subscription = Subscription.new(
        event: @stripe_card.event,
        stripe_card: @stripe_card,
        name: Subscription.humanized_merchant_name(**merchant),
        merchant_network_id: merchant[:network_id],
        merchant_name: merchant[:name] || merchant[:network_id],
        amount_cents: group.first[:amount_cents],
        cadence:,
        cadence_days:,
        source: :charges
      )
      # An active subscription for this card, merchant and amount already exists.
      return unless subscription.valid?

      ActiveRecord::Base.transaction do
        subscription.save!
        group.each { |charge| charge[:hcb_code].update!(subscription:) }
      end
      subscription.sync_charges!

      subscription
    end

    # The typical (lower median) gap has to be one cycle; every gap may span up
    # to MAX_SKIPPED_CYCLES. The buckets' one-cycle windows don't overlap, so at
    # most one bucket can fit.
    def fit_cadence(gaps)
      typical_gap = gaps.sort[(gaps.size - 1) / 2]

      Subscription::CADENCE_DAYS.each do |cadence, days|
        next unless (typical_gap - days).abs <= Subscription::TOLERANCE * days

        return [cadence, days] if gaps.all? { |gap| Subscription.gap_fits_cadence?(gap, days) }
      end

      custom_days = typical_gap.round
      return [:custom, custom_days] if gaps.all? { |gap| Subscription.gap_fits_cadence?(gap, custom_days) }

      nil
    end

  end

end
