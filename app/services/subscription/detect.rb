# frozen_string_literal: true

class Subscription
  # Finds flat-amount subscriptions among a card's settled charges and creates
  # them. A subscription is one merchant charging the exact same amount at least
  # MIN_CHARGES times (two, for a yearly one), with the typical gap close to one
  # of the cadence buckets (or a free-form number of days) and every gap within
  # ±20% of one to three cycles.
  class Detect
    MIN_CHARGES = 3
    # Three yearly charges would need over two years of history, so two a year
    # apart are enough for that cadence.
    MIN_YEARLY_CHARGES = 2
    # Charges closer together than this are repeats (a retry, a double charge),
    # not a cadence.
    MIN_GAP_DAYS = 5
    # Long enough to hold two yearly charges, with tolerance.
    LOOKBACK = 15.months

    def initialize(stripe_card:, merchant_network_id: nil, merchant_name: nil)
      @stripe_card = stripe_card
      @merchant_network_id = merchant_network_id.presence
      @merchant_name = merchant_name.presence
      @merchant_key = Subscription.merchant_key(network_id: merchant_network_id, name: merchant_name)
    end

    # Returns the subscriptions it created.
    def run
      return [] unless @stripe_card.stripe_id.present?

      charges.group_by { |charge| [charge[:merchant_key], charge[:amount_cents]] }.filter_map do |_key, group|
        next if group.size < MIN_YEARLY_CHARGES

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
      charges = without_repeats(group)
      return if charges.size < MIN_YEARLY_CHARGES

      cadence, cadence_days = fit_cadence(charges.each_cons(2).map { |a, b| days_between(a, b) })
      return if cadence.nil?
      return if charges.size < MIN_CHARGES && cadence != :yearly

      merchant = charges.last[:merchant]
      subscription = Subscription.new(
        event: @stripe_card.event,
        stripe_card: @stripe_card,
        merchant_network_id: merchant[:network_id],
        merchant_name: merchant[:name] || merchant[:network_id],
        amount_cents: charges.first[:amount_cents],
        cadence:,
        cadence_days:
      )
      # A subscription for this card, merchant and amount already exists.
      return unless subscription.valid?

      ActiveRecord::Base.transaction do
        subscription.save!
        # Only a foreign key changes, so skip the HcbCode callbacks (see
        # Subscription#link!).
        HcbCode.where(id: charges.map { |charge| charge[:hcb_code].id }).update_all(subscription_id: subscription.id)
      end
      subscription.sync_charges!

      subscription
    end

    # Leaves out charges within MIN_GAP_DAYS of the previous kept one, so a
    # retry or a double charge doesn't stop the rest from forming a cadence
    # (and, since it stays unlinked, from doing so again at every later charge
    # until it ages out of the lookback). A group whose charges are typically
    # that close together isn't a subscription at all.
    def without_repeats(group)
      gaps = group.each_cons(2).map { |a, b| days_between(a, b) }
      return [] if gaps.any? && typical(gaps) < MIN_GAP_DAYS

      group.each_with_object([]) do |charge, kept|
        kept << charge if kept.empty? || days_between(kept.last, charge) >= MIN_GAP_DAYS
      end
    end

    def days_between(a, b)
      (b[:charged_at] - a[:charged_at]) / 1.day
    end

    # The lower median.
    def typical(gaps)
      gaps.sort[(gaps.size - 1) / 2]
    end

    # The typical gap has to be one cycle; every gap may span up to
    # MAX_SKIPPED_CYCLES. The buckets' one-cycle windows don't overlap, so at
    # most one bucket can fit.
    def fit_cadence(gaps)
      typical_gap = typical(gaps)

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
