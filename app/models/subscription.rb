# frozen_string_literal: true

# == Schema Information
#
# Table name: subscriptions
#
#  id                :bigint           not null, primary key
#  amount_cents      :integer          not null
#  cadence_days      :integer          not null
#  confidence        :integer          default(0), not null
#  last_charged_at   :datetime         not null
#  merchant_key      :string           not null
#  name              :string           not null
#  next_expected_at  :datetime         not null
#  payment_rail_type :string           not null
#  variable_amount   :boolean          default(FALSE), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  ledger_id         :bigint           not null
#  payment_rail_id   :bigint           not null
#
# Indexes
#
#  index_subscriptions_on_ledger_id_and_merchant_key  (ledger_id,merchant_key)
#  index_subscriptions_on_payment_rail                (payment_rail_type,payment_rail_id)
#
# Foreign Keys
#
#  fk_rails_...  (ledger_id => ledgers.id)
#
# A recurring charge (Spotify, Vercel, a domain renewal) found by
# Subscription::Detect. For now it is only recorded, so we can see how good
# detection is: nothing behaves differently for a linked charge.
#
# What a subscription is
#
#   ledger            whose money it spends. A subscription belongs to the
#                     ledger, not to a card.
#   merchant_key      who charges (the Stripe merchant network ID)
#   payment_rail      what paid last (a StripeCard today). Updated on every
#                     charge, so it follows a replaced or swapped card.
#   amount_cents      the last amount charged
#   variable_amount   true when the amount changes every time (usage billing)
#   cadence_days      cycle length: 7, 14, 30, 60, 90, 180 or 365
#   next_expected_at  when the next charge is due
#   confidence        0 to 100: how sure we are this is a subscription
#   charges           ledger_items.subscription_id
#
# What is covered, and how
#
#   Flat price on a cadence     A chain of 3 charges of one amount, each a
#                               cycle (within 10%) before the next. 2 for
#                               yearly. Up to 2 skipped cycles.
#   Usage-based / foreign       3 charges of any amount, every gap exactly one
#   currency                    cycle. Marked variable_amount.
#   Late charge (locked card)   Any charge after the due date links. The due
#                               date keeps its day of the month, so the next
#                               on-time charge still links.
#   Price change                A flat subscription takes a charge within 20%
#                               of the last amount.
#   Replaced or swapped card    The card is a signal, not a requirement. The
#                               same cardholder's cards count as one. Someone
#                               else's card needs stronger evidence: the exact
#                               amount on time to join a subscription, 4 exact
#                               charges with no skipped cycle to start one.
#   Several at one merchant     Each chain is its own subscription, even at
#                               the same price on the same card.
#   Retry, one-off purchase     Left out of the chain.
#   In-person purchases         Chip, swipe and tap charges are ignored.
#   Cancelled                   lapsed? once a whole cycle is missed.
#
# Confidence
#
#   Detection decides what could be a subscription; confidence says how sure we
#   are. It is a weighted sum of signals, each between 0 and 1, recomputed on
#   every charge. The weights are first guesses, to be tuned against real data
#   until one cut-off is safe to act on and a lower one is worth asking about.
#
#   charges (25)      more charges, up to 6
#   regularity (20)   how close the gaps are to whole cycles
#   amount (20)       share of charges at the most common amount
#   category (15)     merchant sells subscriptions (software, utilities, ...)
#   card (10)         share of charges on the most common cardholder
#   no_skips (10)     share of gaps that are exactly one cycle
#
# Not covered yet
#
#   ACH and other rails         The schema allows them; nothing detects them.
#   A usage-based subscription moved to a different person's card: found
#   again as new.
#   Cycles other than the seven above.
#   A price change over 20%, or monthly to yearly: found again as a new one.
#   Declined charges            Not recorded.
class Subscription < ApplicationRecord
  has_paper_trail

  CADENCES = {
    7 => "weekly", 14 => "biweekly", 30 => "monthly", 60 => "every two months",
    90 => "quarterly", 180 => "twice a year", 365 => "yearly"
  }.freeze
  # How far a gap or a flat amount may be off, as a fraction.
  TOLERANCE = 0.2

  WEIGHTS = { charges: 25, regularity: 20, amount: 20, category: 15, card: 10, no_skips: 10 }.freeze
  SUBSCRIPTION_CATEGORIES = %w[
    computer_software_stores computer_programming computer_network_services digital_goods_applications
    digital_goods_media telecommunication_services cable_satellite_and_other_pay_television_and_radio
    utilities insurance_default continuity_subscription_merchant
  ].freeze

  belongs_to :ledger
  belongs_to :payment_rail, polymorphic: true
  has_many :ledger_items, class_name: "Ledger::Item", dependent: :nullify, inverse_of: :subscription

  monetize :amount_cents

  validates :name, :merchant_key, presence: true
  validates :cadence_days, :amount_cents, numericality: { only_integer: true, greater_than: 0 }

  def cadence_label
    CADENCES.fetch(cadence_days)
  end

  # Only a lower bound: a charge too soon after the last one is a repeat
  # purchase, but a late one (locked card, lapsed and resumed) still counts.
  def due?(at)
    at >= next_expected_at - (TOLERANCE * cadence_days).days
  end

  def amount_fits?(amount_cents)
    variable_amount? || (amount_cents - self.amount_cents).abs <= TOLERANCE * self.amount_cents
  end

  def lapsed?
    next_expected_at + cadence_days.days < Time.current
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
      regularity: [1 - (off_by / (TOLERANCE * cadence_days)), 0].max,
      amount: share.call(items.map(&:amount_cents)),
      category: charges.last.merchant_category.in?(SUBSCRIPTION_CATEGORIES) ? 1.0 : 0.0,
      card: share.call(charges.map { |charge| charge.stripe_card&.stripe_cardholder_id }),
      no_skips: cycles.empty? ? 1.0 : cycles.count(1).to_f / cycles.size,
    }
  end

  def score!
    update!(confidence: signals.sum { |signal, value| WEIGHTS.fetch(signal) * value }.round)
  end

  # Updates the subscription for a charge, without saving.
  #
  # An on-time charge moves the due date one cycle past itself. A late one fills
  # the cycle it is nearest to and leaves the due dates where they were, because
  # most merchants keep the billing day after a late payment.
  def record_charge(at:, amount_cents:, payment_rail:)
    late_days = (at - next_expected_at) / 1.day
    self.next_expected_at = if late_days <= TOLERANCE * cadence_days
                              at + cadence_days.days
                            else
                              next_expected_at + ((late_days / cadence_days).round + 1) * cadence_days.days
                            end
    self.last_charged_at = at
    self.amount_cents = amount_cents
    self.payment_rail = payment_rail
  end

  # Sets only the foreign key, skipping Ledger::Item callbacks (they re-run the
  # ledger mapper). The `subscription_id: nil` guard makes a second, concurrent
  # link of the same charge a no-op.
  def link!(ledger_item, payment_rail:)
    return if Ledger::Item.where(id: ledger_item.id, subscription_id: nil).update_all(subscription_id: id).zero?

    record_charge(at: ledger_item.datetime, amount_cents: ledger_item.amount_cents.abs, payment_rail:)
    score!
  end

end
