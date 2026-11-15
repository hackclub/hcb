# frozen_string_literal: true

# == Schema Information
#
# Table name: subscriptions
#
#  id                :bigint           not null, primary key
#  amount_cents      :integer          not null
#  cadence_days      :integer          not null
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
#   cadence_days      cycle length: 7, 14, 30, 90, 365, or any other number
#   next_expected_at  when the next charge is due
#   charges           ledger_items.subscription_id
#
# What is covered, and how
#
#   Flat price on a cadence     3 charges of one amount, evenly spaced
#                               (2 for yearly). Up to 2 skipped cycles.
#   Usage-based / foreign       3 charges of any amount, every gap exactly one
#   currency                    weekly-to-yearly cycle. Marked variable_amount.
#   Late charge (locked card)   Any charge after the due date links. The due
#                               date keeps its day of the month, so the next
#                               on-time charge still links.
#   Price change                A flat subscription takes a charge within 20%
#                               of the last amount.
#   Replaced or swapped card    A due subscription takes the charge from any
#                               card on the ledger (same card preferred).
#   Several at one merchant     Each price is its own subscription.
#   Retry / double charge       Charges within 5 days of the last are skipped.
#   In-person purchases         Chip, swipe and tap charges are ignored.
#   Cancelled                   lapsed? once a whole cycle is missed.
#
# Not covered yet
#
#   ACH and other rails         The schema allows them; nothing detects them.
#   Two subscriptions at one merchant for the same price
#   A price change over 20%, or monthly to yearly: found again as a new one.
#   Declined charges            Not recorded.
class Subscription < ApplicationRecord
  has_paper_trail

  CADENCES = { 7 => "weekly", 14 => "biweekly", 30 => "monthly", 90 => "quarterly", 365 => "yearly" }.freeze
  # How far a gap or a flat amount may be off, as a fraction.
  TOLERANCE = 0.2

  belongs_to :ledger
  belongs_to :payment_rail, polymorphic: true
  has_many :ledger_items, class_name: "Ledger::Item", dependent: :nullify, inverse_of: :subscription

  monetize :amount_cents

  validates :name, :merchant_key, presence: true
  validates :cadence_days, :amount_cents, numericality: { only_integer: true, greater_than: 0 }

  def cadence_label
    CADENCES[cadence_days] || "every #{cadence_days} days"
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
    save!
  end

end
