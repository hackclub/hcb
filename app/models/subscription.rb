# frozen_string_literal: true

# == Schema Information
#
# Table name: subscriptions
#
#  id                  :bigint           not null, primary key
#  amount_cents        :integer
#  cadence             :string           not null
#  cadence_days        :integer          not null
#  canceled_at         :datetime
#  last_charged_at     :datetime
#  merchant_name       :string           not null
#  name                :string           not null
#  next_expected_at    :datetime
#  source              :string           default("manual"), not null
#  status              :string           default("active"), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  created_by_id       :bigint
#  event_id            :bigint           not null
#  first_hcb_code_id   :bigint
#  merchant_network_id :string
#  stripe_card_id      :bigint           not null
#
# Indexes
#
#  index_subscriptions_on_created_by_id                           (created_by_id)
#  index_subscriptions_on_event_id                                (event_id)
#  index_subscriptions_on_event_id_and_status                     (event_id,status)
#  index_subscriptions_on_first_hcb_code_id                       (first_hcb_code_id)
#  index_subscriptions_on_stripe_card_id                          (stripe_card_id)
#  index_subscriptions_on_stripe_card_id_and_merchant_network_id  (stripe_card_id,merchant_network_id)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (event_id => events.id)
#  fk_rails_...  (first_hcb_code_id => hcb_codes.id) ON DELETE => nullify
#  fk_rails_...  (stripe_card_id => stripe_cards.id)
#
# A recurring charge on an HCB card (e.g. Spotify, Vercel, a domain renewal).
#
# Charges are linked through `hcb_codes.subscription_id`. The earliest linked
# charge always needs a receipt; every later one is waived. Active subscriptions
# with a flat amount also let a matching charge through a receipt-based card
# lock (see StripeAuthorizationService::Webhook::HandleIssuingAuthorizationRequest).
class Subscription < ApplicationRecord
  has_paper_trail

  include Hashid::Rails
  include PublicIdentifiable
  set_public_id_prefix :sub

  FLAG = :subscriptions_2026_10_13

  CADENCE_DAYS = {
    weekly: 7,
    biweekly: 14,
    monthly: 30,
    quarterly: 90,
    yearly: 365,
  }.freeze
  CYCLES_PER_YEAR = {
    weekly: 52,
    biweekly: 26,
    monthly: 12,
    quarterly: 4,
    yearly: 1,
  }.freeze

  # A charge lines up with the cadence when the gap since the last charge is
  # within ±20% of one, two or three cycles. Allowing skipped cycles keeps a
  # subscription linked after, say, a month with the card frozen.
  TOLERANCE = 0.2
  MAX_SKIPPED_CYCLES = 3

  belongs_to :event
  belongs_to :stripe_card
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :first_hcb_code, class_name: "HcbCode", optional: true

  # Must run before `dependent: :nullify` below clears the links.
  before_destroy :capture_hcb_code_ids, prepend: true
  has_many :hcb_codes, dependent: :nullify, inverse_of: :subscription

  monetize :amount_cents, allow_nil: true

  enum :cadence, {
    weekly: "weekly",
    biweekly: "biweekly",
    monthly: "monthly",
    quarterly: "quarterly",
    yearly: "yearly",
    custom: "custom",
  }, validate: true
  enum :source, { manual: "manual", charges: "charges" }, prefix: true
  enum :status, { active: "active", canceled: "canceled" }

  before_validation :set_cadence_days
  before_validation :set_name

  validates :name, :merchant_name, :cadence, presence: true
  validates :cadence_days, numericality: { only_integer: true, greater_than: 0 }
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :not_a_duplicate, if: :active?

  after_destroy_commit :resync_unlinked_charges

  def self.enabled_for?(event)
    event.present? && Flipper.enabled?(FLAG, event)
  end

  def self.gap_fits_cadence?(gap_days, cadence_days)
    (1..MAX_SKIPPED_CYCLES).any? { |k| (gap_days - (k * cadence_days)).abs <= TOLERANCE * cadence_days }
  end

  def self.merchant_key(network_id:, name:)
    network_id.presence || name.to_s.strip.downcase.presence
  end

  def self.humanized_merchant_name(network_id:, name:)
    looked_up = YellowPages::Merchant.lookup(network_id:).name if network_id.present?
    looked_up.presence || name&.titleize || network_id
  end

  def matches?(merchant_network_id:, merchant_name:, amount_cents:, at:)
    active? &&
      merchant_matches?(merchant_network_id:, merchant_name:) &&
      amount_matches?(amount_cents) &&
      timing_ok?(at)
  end

  def merchant_matches?(merchant_network_id:, merchant_name:)
    if self.merchant_network_id.present? && merchant_network_id.present?
      self.merchant_network_id == merchant_network_id.to_s
    else
      merchant_name.present? && self.merchant_name.to_s.strip.casecmp?(merchant_name.to_s.strip)
    end
  end

  def amount_matches?(cents)
    amount_cents.nil? || amount_cents == cents.to_i.abs
  end

  def timing_ok?(at)
    return true if last_charged_at.nil? || at.nil?

    gap_days = (at - last_charged_at).abs / 1.day
    self.class.gap_fits_cadence?(gap_days, cadence_days)
  end

  def cycles_per_year
    CYCLES_PER_YEAR[cadence&.to_sym] || (365.0 / cadence_days)
  end

  def yearly_cents
    return if amount_cents.nil?

    (amount_cents * cycles_per_year).round
  end

  def monthly_cents
    return if amount_cents.nil?

    (amount_cents * cycles_per_year / 12.0).round
  end

  def cadence_label
    return "every #{cadence_days} days" if custom?

    cadence.humanize(capitalize: false)
  end

  def merchant_key
    self.class.merchant_key(network_id: merchant_network_id, name: merchant_name)
  end

  # The single writer of derived state (first charge, last/next charge times),
  # followed by a refresh of every linked charge's receipt requirement and
  # card-locking deadline.
  def sync_charges!
    charges = hcb_codes.reload.to_a.sort_by { |hcb_code| [charged_at(hcb_code), hcb_code.id] }

    self.first_hcb_code = charges.first
    self.last_charged_at = charges.last&.then { |hcb_code| charged_at(hcb_code) }
    self.next_expected_at = last_charged_at && (last_charged_at + cadence_days.days)
    save!

    charges.each { |hcb_code| hcb_code.refresh_receipt_state!(enqueue_unlock: false) }
    CardLocking::ReceiptResolution.enqueue_unlock(stripe_card.user)
  end

  def link!(hcb_code)
    hcb_code.update!(subscription: self)
    sync_charges!
  end

  def cancel!
    update!(status: :canceled, canceled_at: Time.current)
  end

  private

  def charged_at(hcb_code)
    hcb_code.datetime || hcb_code.created_at
  end

  def set_cadence_days
    self.cadence_days = CADENCE_DAYS[cadence.to_sym] if cadence.present? && !custom?
  end

  def set_name
    self.name = merchant_name if name.blank?
  end

  def not_a_duplicate
    return if stripe_card_id.nil?

    duplicate = Subscription.active
                            .where(stripe_card_id:, amount_cents:)
                            .where.not(id:)
                            .any? { |other| other.merchant_key == merchant_key }

    errors.add(:base, "This card already has an active subscription for this merchant and amount") if duplicate
  end

  def capture_hcb_code_ids
    @unlinked_hcb_code_ids = hcb_code_ids
  end

  def resync_unlinked_charges
    return if @unlinked_hcb_code_ids.blank?

    Subscription::ResyncChargesJob.perform_later(hcb_code_ids: @unlinked_hcb_code_ids)
  end

end
