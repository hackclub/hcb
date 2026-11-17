# frozen_string_literal: true

# == Schema Information
#
# Table name: ledger_subscriptions
#
#  id                :bigint           not null, primary key
#  amount_cents      :integer          not null
#  cadence_days      :integer          not null
#  confidence        :integer          default(0), not null
#  last_charged_at   :datetime         not null
#  merchant_key      :string           not null
#  name              :string           not null
#  next_expected_at  :datetime         not null
#  variable_amount   :boolean          default(FALSE), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  ledger_id         :bigint           not null
#  payment_rail_id   :bigint           not null
#  payment_rail_type :string           not null
#
# Indexes
#
#  index_ledger_subscriptions_on_ledger_id_and_merchant_key  (ledger_id,merchant_key)
#  index_ledger_subscriptions_on_payment_rail                (payment_rail_type,payment_rail_id)
#
# Foreign Keys
#
#  fk_rails_...  (ledger_id => ledgers.id)
#
# A recurring charge (Spotify, Vercel, a domain renewal) found by
# Ledger::Subscription::Detect. For now it is only recorded, so we can see how good
# detection is: nothing behaves differently for a linked charge.
#
# What a subscription is
#
#   ledger            whose money it spends. A subscription belongs to the
#                     ledger, not to a card.
#   merchant_key      who charges (the Stripe merchant network ID)
#   payment_rail      the card of the cardholder it follows (a StripeCard
#                     today), from their latest charge. It follows their
#                     replaced card, and moves to someone else's card when
#                     that person takes the subscription over.
#   amount_cents      the last amount charged
#   variable_amount   true when the amount changes every time (usage billing)
#   cadence_days      cycle length: one of CADENCES
#   next_expected_at  when the next charge is due
#   confidence        0 to 100: how sure we are this is a subscription
#   charges           ledger_items.subscription_id
#
# What is covered, and how (the thresholds are constants, here and in Detect)
#
#   Flat price on a cadence     A chain of Detect::MIN_CHARGES charges of one
#                               amount, each a cycle (within
#                               Detect::CHAIN_TOLERANCE) before the next, or
#                               Detect::MIN_YEARLY_CHARGES for yearly. Up to
#                               Detect::MAX_CYCLES - 1 skipped cycles.
#   Usage-based / foreign       Detect::MIN_CHARGES charges of amounts that
#   currency                    vary, every gap one cycle. Marked
#                               variable_amount.
#   Late charge (locked card)   Any charge after the due date links. It pays
#                               for the cycle it is late for and the due dates
#                               stay on their grid, so the next on-time charge
#                               still links. A charge over half a cycle late
#                               that comes a whole number of cycles after the
#                               last one moves the billing day.
#   Price change                A flat subscription takes a charge within
#                               AMOUNT_TOLERANCE of the last amount.
#   Replaced or swapped card    The card is a signal, not a requirement. The
#                               same cardholder's cards count as one. Someone
#                               else's charge joins only at the exact amount,
#                               once the cardholder has missed a whole cycle
#                               and before the subscription lapses, and takes
#                               it over. Starting one from several
#                               cardholders' charges takes
#                               Detect::MIN_OTHER_CARD_CHARGES exact charges
#                               with no skipped cycle.
#   Several at one merchant     Each chain is its own subscription, even at
#                               the same price on the same card, or on two
#                               people's cards.
#   Retry, one-off purchase     Left out of the chain.
#   In-person purchases         Chip, swipe and tap charges are ignored.
#   Moved to another ledger,    The charge leaves the subscription, which is
#   refunded, or paid in person recomputed from the charges it has left. A
#                               partial refund leaves it in: amounts are what
#                               each charge was for.
#   Cancelled                   lapsed? once a whole cycle is missed.
#
# Confidence
#
#   Detection decides what could be a subscription; confidence says how sure we
#   are. It adds up points for signals that each score between 0 and 1, out of
#   WEIGHTS, recomputed on every charge. The weights are first guesses, to be
#   tuned against real data until one cut-off is safe to act on and a lower one
#   is worth asking about.
#
#   charges           more charges, up to 6
#   regularity        how close the gaps are to whole cycles
#   amount            share of charges at the most common amount
#   category          merchant sells subscriptions (software, utilities, ...)
#   card              share of charges on the most common cardholder
#   no_skips          share of gaps that are exactly one cycle
#
# Not covered yet
#
#   ACH and other rails         The schema allows them; nothing detects them.
#   A usage-based subscription moved to a different person's card: found
#   again as new. A flat one moved to someone else's card leaves out the
#   first charge on it, or is found again as new when their billing day
#   differs.
#   A payment over half a cycle late that lands near a whole cycle after the
#   last charge: read as a moved billing day, so the next charge on the old
#   day is left out.
#   Usage billing that repeats one amount (a minimum fee) in over
#   Detect::MAX_REPEATED_AMOUNT_SHARE of its charges: read as a flat price.
#   Cycles other than CADENCES.
#   A price change over AMOUNT_TOLERANCE, or monthly to yearly: found again
#   as a new one.
#   A refund without an authorization (its own transaction): the charge it
#   refunds stays linked.
#   Declined charges            Not recorded.
class Ledger
  class Subscription < ApplicationRecord
    self.table_name = "ledger_subscriptions"

    # Versions when the subscription moves to another card (or its cadence or
    # kind changes), not for the due date, amount and score every charge moves.
    has_paper_trail only: %i[payment_rail_type payment_rail_id cadence_days variable_amount]

    CADENCES = {
      7 => "weekly", 14 => "every two weeks", 30 => "monthly", 60 => "every two months",
      90 => "quarterly", 180 => "twice a year", 365 => "yearly"
    }.freeze
    # How far a charge may be from its due date, as a fraction of the cycle.
    TIMING_TOLERANCE = 0.2
    # How far a flat subscription's next charge may be from the last amount, as
    # a fraction of it.
    AMOUNT_TOLERANCE = 0.2

    WEIGHTS = { charges: 25, regularity: 20, amount: 20, category: 15, card: 10, no_skips: 10 }.freeze
    SUBSCRIPTION_CATEGORIES = %w[
      computer_software_stores computer_programming computer_network_services digital_goods_applications
      digital_goods_media telecommunication_services cable_satellite_and_other_pay_television_and_radio
      utilities insurance_default direct_marketing_subscription
    ].freeze

    belongs_to :ledger
    belongs_to :payment_rail, polymorphic: true
    has_many :ledger_items, class_name: "Ledger::Item", dependent: :nullify, inverse_of: :subscription

    monetize :amount_cents

    validates :name, :merchant_key, presence: true
    validates :cadence_days, :amount_cents, numericality: { only_integer: true, greater_than: 0 }

    # Takes a charge out of its subscription: when it moves to another ledger
    # or none, when it's refunded, or when it turns out to have been paid in
    # person. Only the foreign key changes here, so the write that called this
    # can't fail on subscription data: the subscription is recomputed, and the
    # charge detected again (where it is now, if anywhere), in jobs queued once
    # that write commits.
    def self.unlink(ledger_item)
      # Locked, so a detection job linking this charge right now finishes
      # first. FOR NO KEY UPDATE, like the update below, so a concurrent insert
      # that references the item (a transaction settling onto it) isn't blocked.
      subscription_id = Ledger::Item.where(id: ledger_item.id).lock("FOR NO KEY UPDATE").pick(:subscription_id)
      return if subscription_id.nil?

      Ledger::Item.where(id: ledger_item.id, subscription_id:).update_all(subscription_id: nil)
      RecomputeJob.perform_later(subscription_id)
      DetectJob.perform_later(ledger_item)
    end

    def cadence_label
      CADENCES.fetch(cadence_days)
    end

    # Only a lower bound: a charge too soon after the last one is a repeat
    # purchase, but a late one (locked card, lapsed and resumed) still counts.
    def due?(at)
      at >= next_expected_at - (TIMING_TOLERANCE * cadence_days).days
    end

    def amount_fits?(amount_cents)
      variable_amount? || (amount_cents - self.amount_cents).abs <= AMOUNT_TOLERANCE * self.amount_cents
    end

    def lapsed?
      next_expected_at + cadence_days.days < Time.current
    end

    # Past the due date, but not by a whole cycle yet.
    def overdue?
      next_expected_at.past? && !lapsed?
    end

    # The confidence signals, each between 0 and 1. See WEIGHTS.
    def signals
      items = ledger_items.includes(linked_object: :stripe_card).order(:datetime, :id).to_a
      charges = items.map(&:linked_object)
      gaps = items.each_cons(2).map { |a, b| (b.datetime - a.datetime) / 1.day }
      cycles = gaps.map { |gap| [(gap / cadence_days).round, 1].max }
      off_by = gaps.zip(cycles).sum { |gap, k| (gap - (k * cadence_days)).abs } / [gaps.size, 1].max
      share = ->(values) { values.tally.values.max.to_f / values.size }

      {
        charges: [items.size - 1, 5].min / 5.0,
        regularity: [1 - (off_by / (TIMING_TOLERANCE * cadence_days)), 0].max,
        amount: share.call(items.map(&:amount_cents)),
        category: charges.last.merchant_category.in?(SUBSCRIPTION_CATEGORIES) ? 1.0 : 0.0,
        card: share.call(charges.map { |charge| charge.stripe_card&.stripe_cardholder_id }),
        no_skips: cycles.empty? ? 1.0 : cycles.count(1).to_f / cycles.size,
      }
    end

    # The points each signal earns, out of its weight. They add up to the
    # confidence.
    def points
      signals.to_h { |signal, value| [signal, (WEIGHTS.fetch(signal) * value).round] }
    end

    def score!
      update!(confidence: points.values.sum)
    end

    # Updates the subscription for a charge, without saving.
    #
    # An on-time charge moves the due date one cycle past itself. So does a charge
    # over half a cycle late that comes a whole number of cycles after the last
    # one: the merchant bills on that day now (a moved billing day, a skipped
    # cycle, a resumed subscription). Any other late charge pays for the last
    # cycle that came due before it and leaves the due dates on their grid,
    # because most merchants keep the billing day after a late payment.
    def record_charge(at:, amount_cents:, payment_rail:)
      late_days = (at - next_expected_at) / 1.day
      self.next_expected_at = if late_days <= TIMING_TOLERANCE * cadence_days || moved_billing_day?(at, late_days)
                                at + cadence_days.days
                              else
                                next_expected_at + ((late_days / cadence_days).floor + 1) * cadence_days.days
                              end
      self.last_charged_at = at
      self.amount_cents = amount_cents
      self.payment_rail = payment_rail
    end

    # Sets the due date, the last charge and the payment rail from these charges,
    # oldest first, without saving. Amounts are what each charge was for,
    # before any partial refund.
    def replay(items)
      self.next_expected_at = items.first.datetime
      items.each do |item|
        record_charge(at: item.datetime, amount_cents: item.linked_object.amount_cents, payment_rail: item.linked_object.stripe_card)
      end
    end

    # Charges that can be linked: eligible, not linked yet, and paid online.
    # Checked again in the update that links them, so a charge refunded, linked
    # elsewhere, or found to be paid in person after detection looked at it is
    # left out.
    def self.linkable_items
      Ledger::Item.subscription_eligible.where(subscription_id: nil, linked_object_id: CardCharge.card_not_present.select(:id))
    end

    # Sets only the foreign key, skipping Ledger::Item callbacks (they re-run the
    # ledger mapper). The guards (see linkable_items) make a second, concurrent
    # link of the same charge a no-op, and leave out a charge that changed or
    # moved to another ledger after detection looked at it. The row lock (which reloads the
    # subscription) keeps a concurrent link or recompute from overwriting this
    # one.
    def link!(ledger_item, payment_rail:)
      with_lock do
        linked = self.class.linkable_items.where(id: ledger_item.id).with_primary_ledger(ledger_id).update_all(subscription_id: id)
        if linked.positive?
          record_charge(at: ledger_item.datetime, amount_cents: ledger_item.linked_object.amount_cents, payment_rail:)
          score!
        end
      end
    end

    # Replays the charges that still spend money, after one leaves, and deletes
    # the subscription when none are left.
    def recompute!
      with_lock do
        items = ledger_items.subscription_eligible.order(:datetime, :id).includes(linked_object: [:stripe_card, :raw_stripe_transactions]).to_a
        if items.empty?
          destroy!
        else
          replay(items)
          score!
        end
      end
    end

    private

    def moved_billing_day?(at, late_days)
      days = (at - last_charged_at) / 1.day
      late_days > cadence_days / 2.0 &&
        (days - ((days / cadence_days).round * cadence_days)).abs <= Detect::CHAIN_TOLERANCE * cadence_days
    end

  end

end
