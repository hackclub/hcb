# frozen_string_literal: true

# == Schema Information
#
# Table name: wise_transfers
#
#  id                               :bigint           not null, primary key
#  aasm_state                       :string
#  address_city                     :string
#  address_line1                    :string
#  address_line2                    :string
#  address_postal_code              :string
#  address_state                    :string
#  amount_cents                     :integer          not null
#  approved_at                      :datetime
#  bank_name                        :string
#  currency                         :string           not null
#  payment_for                      :string           not null
#  quoted_usd_amount_cents          :integer
#  recipient_country                :integer          not null
#  recipient_email                  :string           not null
#  recipient_information_ciphertext :text
#  recipient_name                   :string           not null
#  recipient_phone_number           :text
#  return_reason                    :text
#  sent_at                          :datetime
#  usd_amount_cents                 :integer
#  created_at                       :datetime         not null
#  updated_at                       :datetime         not null
#  event_id                         :bigint           not null
#  user_id                          :bigint           not null
#  wise_id                          :text
#  wise_recipient_id                :text
#
# Indexes
#
#  index_wise_transfers_on_event_id  (event_id)
#  index_wise_transfers_on_user_id   (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#  fk_rails_...  (user_id => users.id)
#
class WiseTransfer < ApplicationRecord
  include PgSearch::Model
  pg_search_scope :search_recipient, against: [:recipient_name, :recipient_email]

  has_encrypted :recipient_information, type: :json

  include AASM
  include Freezable

  include HasWiseRecipient

  include PublicIdentifiable
  set_public_id_prefix :wse

  belongs_to :event
  belongs_to :user
  has_paper_trail

  has_one :canonical_pending_transaction

  has_one :reimbursement_payout_holding, class_name: "Reimbursement::PayoutHolding", inverse_of: :wise_transfer, required: false

  monetize :amount_cents, as: "amount", with_model_currency: :currency
  monetize :usd_amount_cents, as: "usd_amount", allow_nil: true

  validates :amount_cents, numericality: { greater_than_or_equal_to: 100, message: "must be at least $1" }
  validates :usd_amount_cents, numericality: { greater_than_or_equal_to: 0, message: "must be positive" }, allow_nil: true
  validates :quoted_usd_amount_cents, numericality: { greater_than_or_equal_to: 0, message: "must be positive" }, allow_nil: true

  include PublicActivity::Model
  tracked owner: proc { |controller, record| controller&.current_user }, event_id: proc { |controller, record| record.event.id }, only: [:create]

  WISE_ID_FORMAT = /\A\d+\z/
  before_validation(:normalize_wise_id)
  validates(:wise_id, format: { with: WISE_ID_FORMAT, message: "is not a valid Wise ID" }, allow_nil: true)
  validates(:wise_id, presence: true, if: :processed?)

  WISE_RECIPIENT_ID_FORMAT = /\A[\h-]{36}\z/
  before_validation(:normalize_wise_recipient_id)
  validates(:wise_recipient_id, format: { with: WISE_RECIPIENT_ID_FORMAT, message: "is not a valid Wise recipient ID" }, allow_nil: true)
  validates(:wise_recipient_id, presence: true, if: :processed?)

  after_create do
    generate_quote!

    create_canonical_pending_transaction!(
      event:,
      amount_cents: -quoted_usd_amount_cents,
      memo: "Wise to #{recipient_name} (#{Money.from_cents(amount_cents, currency).format} #{currency})",
      date: created_at
    )
  end

  after_update do
    canonical_pending_transaction.update(amount_cents: -usd_amount_cents) if saved_change_to_usd_amount_cents? && usd_amount_cents.present?
  end

  validates_presence_of :payment_for, :recipient_name, :recipient_email
  validates :recipient_email, email_with_tld: true
  normalizes :recipient_email, with: ->(recipient_email) { recipient_email.strip.downcase }

  # Flowchart: https://www.figma.com/board/Hf3wy2qhR8rH9OAYUCrkoQ/Wise-transfer-flowchart?node-id=0-1&t=nBQqJBuASTxeCObj-1
  aasm timestamps: true, whiny_persistence: true do
    state :pending, initial: true
    state :approved
    state :rejected
    state :sent
    state :deposited
    state :failed

    event :mark_approved do
      transitions from: :pending, to: :approved
    end

    event :mark_rejected do
      after do
        canonical_pending_transaction.decline!
      end
      transitions from: [:pending, :approved], to: :rejected
    end

    event :mark_sent do
      after do
        canonical_pending_transaction.update(amount_cents: -usd_amount_cents)
      end
      transitions from: [:approved], to: :sent
    end

    event :mark_deposited do
      transitions from: :sent, to: :deposited
    end

    event :mark_failed do
      transitions from: [:pending, :approved, :sent, :approved], to: :failed
      after do |reason = nil|
        WiseTransferMailer.with(wise_transfer: self, reason:).notify_failed.deliver_later
        update(return_reason: reason)
        canonical_pending_transaction.decline!
      end
    end
  end

  def processed?
    sent? || deposited?
  end

  validates :amount_cents, numericality: { greater_than: 0, message: "must be positive!" }
  validates :usd_amount_cents, numericality: { less_than: 50_000_00, message: "must be less than $50,000" }, allow_nil: true

  alias_attribute :name, :recipient_name

  include HasHcbCode
  has_hcb_code TransactionGroupingEngine::Calculate::HcbCode::WISE_TRANSFER_CODE, persisted_only: true

  def admin_dropdown_description
    "#{usd_amount.format} (#{Money.from_cents(amount_cents, currency).format} #{currency}) to #{recipient_name} (#{recipient_email}) from #{event.name}"
  end

  def status_color
    if pending?
      :warning
    elsif approved?
      :blue
    elsif sent?
      :purple
    elsif rejected? || failed?
      :error
    elsif deposited?
      :success
    else
      :muted
    end
  end
  alias_method :state_color, :status_color

  def state_text
    aasm_state.humanize
  end

  def last_user_change_to(...)
    user_id = versions.where_object_changes_to(...).last&.whodunnit

    user_id && User.find(user_id)
  end

  def self.generate_detailed_quote(initial_local_amount)
    conn = Faraday.new url: "https://api.wise.com" do |f|
      f.request :json
      f.response :raise_error
      f.response :json
    end

    response = conn.post("/v3/quotes", {
                           sourceCurrency: "USD",
                           targetCurrency: initial_local_amount.currency_as_string,
                           targetAmount: initial_local_amount.dollars
                         })

    payment_option = response.body["paymentOptions"].first
    price_after_all_fees = Money.from_dollars(payment_option["sourceAmount"], "USD")
    fees = payment_option["price"]["items"]

    pay_in_fee = Money.from_dollars(fees.find { |fee| fee["type"] == "PAYIN" }["value"]["amount"], "USD")
    unadjusted_fee_total = fees.sum { |fee| Money.from_dollars(fee["value"]["amount"], "USD") }

    without_fees_usd_amount = price_after_all_fees - unadjusted_fee_total

    price_before_ach_fee = price_after_all_fees - pay_in_fee
    wise_ach_fee = 1.0017 # The Wise API doesn't show profile-specific payment methods like ACH, but the ACH fee is a standard 0.17% of the amount sent.

    with_fees_usd_amount = price_before_ach_fee * wise_ach_fee

    fees_usd_amount = with_fees_usd_amount - without_fees_usd_amount

    {
      initial_local_amount:,
      without_fees_usd_amount:,
      with_fees_usd_amount:,
      fees_usd_amount:
    }
  end

  def self.generate_quote(money)
    generate_detailed_quote(money)[:with_fees_usd_amount]
  end

  def estimated_usd_amount_cents
    @estimated_usd_amount_cents ||= WiseTransfer.generate_quote(Money.from_cents(amount_cents, currency)).cents
  end

  def usd_amount_cents_or_quoted
    usd_amount_cents || quoted_usd_amount_cents
  end

  def generate_quote!
    update!(quoted_usd_amount_cents: estimated_usd_amount_cents) unless quoted_usd_amount_cents.present?
  end

  def wise_url
    return nil unless wise_id.present?

    "https://wise.com/transactions/activities/by-resource/TRANSFER/#{CGI.escape(wise_id)}"
  end

  def wise_recipient_url
    return nil unless wise_recipient_id.present?

    "https://wise.com/recipients/#{CGI.escape(wise_recipient_id)}"
  end

  private

  WISE_ID_REGEXPS = [
    /wise\.com\/transactions\/activities\/by-resource\/transfer\/(\d+)/i,
    /wise\.com\/success\/transfer\/(\d+)/i
  ].freeze

  def normalize_wise_id
    return unless wise_id_changed? && wise_id.present?

    normalized = wise_id.strip

    if normalized =~ WISE_ID_FORMAT
      self.wise_id = normalized
      return
    end

    WISE_ID_REGEXPS.each do |regexp|
      match = regexp.match(normalized)

      if match
        self.wise_id = match[1]
        break
      end
    end
  end

  WISE_RECIPIENT_ID_REGEXP = /wise\.com\/recipients\/([\h-]{36})/

  def normalize_wise_recipient_id
    return unless wise_recipient_id_changed? && wise_recipient_id.present?

    normalized = wise_recipient_id.strip

    if normalized =~ WISE_RECIPIENT_ID_FORMAT
      self.wise_recipient_id = normalized
      return
    end

    match = WISE_RECIPIENT_ID_REGEXP.match(normalized)
    self.wise_recipient_id = match[1] if match
  end

end
