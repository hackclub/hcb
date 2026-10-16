# frozen_string_literal: true

# == Schema Information
#
# Table name: subscriptions
#
#  id                  :bigint           not null, primary key
#  amount_cents        :integer          not null
#  cadence             :string           not null
#  cadence_days        :integer          not null
#  last_charged_at     :datetime
#  merchant_name       :string           not null
#  next_expected_at    :datetime
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  event_id            :bigint           not null
#  merchant_network_id :string
#  stripe_card_id      :bigint           not null
#
# Indexes
#
#  index_subscriptions_on_event_id                                (event_id)
#  index_subscriptions_on_stripe_card_id                          (stripe_card_id)
#  index_subscriptions_on_stripe_card_id_and_merchant_network_id  (stripe_card_id,merchant_network_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#  fk_rails_...  (stripe_card_id => stripe_cards.id)
#
# A recurring card charge (e.g. Spotify, Vercel, a domain renewal) found by
# Subscription::Detect: one merchant charging a card the same amount on a
# cadence. Charges are linked through `hcb_codes.subscription_id`.
#
# For now this only records what detection finds, so we can see how well it
# works. Nothing (receipts, card locking) behaves differently for a linked
# charge.
class Subscription < ApplicationRecord
  has_paper_trail

  CADENCE_DAYS = {
    weekly: 7,
    biweekly: 14,
    monthly: 30,
    quarterly: 90,
    yearly: 365,
  }.freeze

  # A charge lines up with the cadence once at least a cycle (less 20%) has
  # passed since the last charge. Only the lower bound is checked: a charge
  # too soon after the last one is a repeat purchase, not the subscription,
  # whereas a long gap (a frozen card, a lapsed subscription that was later
  # resumed) shouldn't stop the next charge from linking and bringing
  # last_charged_at back up to date. An upper bound would leave the
  # subscription stuck on a stale last_charged_at after one off-cadence
  # charge, with nothing able to link ever again.
  TOLERANCE = 0.2
  # When detecting a subscription, each gap between consecutive charges may
  # span up to this many cycles (a skipped month, say).
  MAX_SKIPPED_CYCLES = 3

  belongs_to :event
  belongs_to :stripe_card
  has_many :hcb_codes, dependent: :nullify, inverse_of: :subscription

  monetize :amount_cents

  enum :cadence, {
    weekly: "weekly",
    biweekly: "biweekly",
    monthly: "monthly",
    quarterly: "quarterly",
    yearly: "yearly",
    custom: "custom",
  }, validate: true

  before_validation :set_cadence_days

  validates :merchant_name, presence: true
  validates :cadence_days, numericality: { only_integer: true, greater_than: 0 }
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validate :not_a_duplicate

  def self.gap_fits_cadence?(gap_days, cadence_days)
    (1..MAX_SKIPPED_CYCLES).any? { |k| (gap_days - (k * cadence_days)).abs <= TOLERANCE * cadence_days }
  end

  def self.merchant_key(network_id:, name:)
    network_id.presence || name.to_s.strip.downcase.presence
  end

  def matches?(merchant_network_id:, merchant_name:, amount_cents:, at:)
    merchant_matches?(merchant_network_id:, merchant_name:) &&
      amount_cents.to_i.abs == self.amount_cents &&
      timing_ok?(at)
  end

  def merchant_matches?(merchant_network_id:, merchant_name:)
    if self.merchant_network_id.present? && merchant_network_id.present?
      self.merchant_network_id == merchant_network_id.to_s
    else
      merchant_name.present? && self.merchant_name.to_s.strip.casecmp?(merchant_name.to_s.strip)
    end
  end

  def timing_ok?(at)
    return true if last_charged_at.nil? || at.nil?

    gap_days = (at - last_charged_at).abs / 1.day
    gap_days >= (1 - TOLERANCE) * cadence_days
  end

  def cadence_label
    return "every #{cadence_days} days" if custom?

    cadence.humanize(capitalize: false)
  end

  def merchant_key
    self.class.merchant_key(network_id: merchant_network_id, name: merchant_name)
  end

  # In the shape of a Stripe `merchant_data` hash, for the merchant helpers.
  def merchant
    { "network_id" => merchant_network_id, "name" => merchant_name }
  end

  # Recomputes the last and next expected charge times from the linked charges.
  def sync_charges!
    last_charged_at = hcb_codes.reload.map { |hcb_code| hcb_code.datetime || hcb_code.created_at }.max

    update!(last_charged_at:, next_expected_at: last_charged_at && (last_charged_at + cadence_days.days))
  end

  # Linking only stamps a foreign key nothing else reacts to, so it skips the
  # HcbCode callbacks: saving an HcbCode touches its ledger item, which re-runs
  # the ledger mapper and enqueues card-locking jobs.
  def link!(hcb_code)
    hcb_code.update_column(:subscription_id, id)
    sync_charges!
  end

  private

  def set_cadence_days
    self.cadence_days = CADENCE_DAYS[cadence.to_sym] if cadence.present? && !custom?
  end

  def not_a_duplicate
    return if stripe_card_id.nil?

    duplicate = Subscription.where(stripe_card_id:, amount_cents:)
                            .where.not(id:)
                            .any? { |other| other.merchant_key == merchant_key }

    errors.add(:base, "This card already has a subscription for this merchant and amount") if duplicate
  end

end
