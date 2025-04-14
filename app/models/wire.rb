# frozen_string_literal: true

# == Schema Information
#
# Table name: wires
#
#  id                        :bigint           not null, primary key
#  aasm_state                :string           not null
#  account_number_bidx       :string           not null
#  account_number_ciphertext :string           not null
#  address_city              :string
#  address_line1             :string
#  address_line2             :string
#  address_postal_code       :string
#  address_state             :string
#  amount_cents              :integer          not null
#  approved_at               :datetime
#  bic_code_bidx             :string           not null
#  bic_code_ciphertext       :string           not null
#  currency                  :string           default("USD"), not null
#  memo                      :string           not null
#  payment_for               :string           not null
#  recipient_country         :integer
#  recipient_email           :string           not null
#  recipient_information     :jsonb
#  recipient_name            :string           not null
#  return_reason             :text
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  column_id                 :text
#  event_id                  :bigint           not null
#  user_id                   :bigint           not null
#
# Indexes
#
#  index_wires_on_column_id  (column_id) UNIQUE
#  index_wires_on_event_id   (event_id)
#  index_wires_on_user_id    (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#  fk_rails_...  (user_id => users.id)
#
class Wire < ApplicationRecord
  has_paper_trail

  include PgSearch::Model
  pg_search_scope :search_recipient, against: [:recipient_name, :recipient_email]
  has_encrypted :account_number, :bic_code
  blind_index :account_number, :bic_code

  has_one :reimbursement_payout_holding, class_name: "Reimbursement::PayoutHolding", inverse_of: :wire, required: false

  validates_length_of :payment_for, maximum: 140

  include AASM
  include Freezable

  include HasWireRecipient

  belongs_to :event
  belongs_to :user

  has_one :canonical_pending_transaction

  monetize :amount_cents, as: "amount", with_model_currency: :currency


  include PublicActivity::Model
  tracked owner: proc{ |controller, record| controller&.current_user }, event_id: proc { |controller, record| record.event.id }, only: [:create]

  after_create do
    create_canonical_pending_transaction!(
      event:,
      amount_cents: -1 * usd_amount_cents,
      memo: "Wire to #{recipient_name}".strip.upcase,
      date: created_at
    )
  end

  validates_presence_of :memo, :payment_for, :recipient_name, :recipient_email
  validates :recipient_email, format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" }
  normalizes :recipient_email, with: ->(recipient_email) { recipient_email.strip.downcase }

  validate on: :create do
    if !user.admin? && usd_amount_cents < (Event.find(event.id).minimum_wire_amount_cents)
      errors.add(:amount, " must be more than or equal to #{ApplicationController.helpers.render_money event.minimum_wire_amount_cents} (USD).")
    end
  end

  aasm timestamps: true, whiny_persistence: true do
    state :pending, initial: true
    state :approved
    state :rejected
    state :deposited
    state :failed

    event :mark_approved do
      transitions from: :pending, to: :approved
    end

    event :mark_rejected do
      after do
        canonical_pending_transaction.decline!
        create_activity(key: "wire.rejected")
      end
      transitions from: [:pending, :approved], to: :rejected
    end

    event :mark_deposited do
      transitions from: :approved, to: :deposited
    end

    event :mark_failed do
      transitions from: [:deposited, :approved], to: :failed
      after do |reason = nil|
        if reimbursement_payout_holding.present?
          ReimbursementMailer.with(reimbursement_payout_holding:, reason:).wire_failed.deliver_later
          reimbursement_payout_holding.mark_failed!
        else
          WireMailer.with(wire: self, reason:).notify_failed.deliver_later
        end
        create_activity(key: "wire.failed", owner: nil)
        update(return_reason: reason)
      end
    end
  end

  validates :amount_cents, numericality: { greater_than: 0, message: "must be positive!" }

  validate on: :create do
    if usd_amount_cents > event.balance_available_v2_cents
      errors.add(:base, "You don't have enough money to send this transfer! Your balance is #{(event.balance_available_v2_cents / 100).to_money.format}. At current exchange rates, this transfer would cost #{(usd_amount_cents / 100).to_money.format} (USD).")
    end
  end

  def state
    if pending?
      :muted
    elsif rejected? || failed?
      :error
    elsif deposited?
      :success
    else
      :info
    end
  end

  def state_text
    aasm_state.humanize
  end

  alias_attribute :name, :recipient_name

  def hcb_code
    "HCB-#{TransactionGroupingEngine::Calculate::HcbCode::WIRE_CODE}-#{id}"
  end

  def admin_dropdown_description
    "#{Money.from_cents(amount_cents, currency).format} to #{recipient_name} (#{recipient_email}) from #{event.name}"
  end

  def local_hcb_code
    return nil unless persisted? # don't access local_hcb_code before saving.

    @local_hcb_code ||= HcbCode.find_or_create_by(hcb_code:)
  end

  def usd_amount_cents
    return -1 * local_hcb_code.amount_cents unless local_hcb_code.nil? || local_hcb_code.no_transactions?

    eu_bank = EuCentralBank.new
    eu_bank.update_rates
    eu_bank.exchange(amount_cents, currency, "USD").cents
  end

  def send_wire!
    return unless may_mark_approved?

    account_number_id = (event.column_account_number || event.create_column_account_number)&.column_id

    column_counterparty = ColumnService.post("/counterparties", {
      idempotency_key: self.id.to_s,
      routing_number_type: "bic",
      routing_number: bic_code,
      account_number:,
      wire: {
        beneficiary_name: recipient_name,
        beneficiary_email: recipient_email,
        beneficiary_address: {
          line_1: address_line1,
          line_2: address_line2,
          city: address_city,
          state: address_state,
          postal_code: address_postal_code,
          country_code: recipient_country
        },
        beneficiary_legal_id: recipient_information[:legal_id],
        beneficiary_type: recipient_information[:legal_type],
        local_bank_code: recipient_information[:local_bank_code],
        local_account_number: recipient_information[:local_account_number],
        account_type: recipient_information[:account_type]
      }.compact_blank
    }.compact_blank)

    column_wire_transfer = ColumnService.post("/transfers/international-wire", {
      idempotency_key: self.id.to_s,
      amount: amount_cents,
      currency_code: currency,
      counterparty_id: column_counterparty["id"],
      description: payment_for,
      account_number_id:,
      message_to_beneficiary_bank: "please contact with the beneficiary",
      remittance_info: {
        general_info: recipient_information[:remittance_info]
      },
      purpose_code: recipient_information[:purpose_code]
    }.compact_blank)

    self.column_id = column_wire_transfer["id"]
    mark_approved
    save!
  end

  def last_user_change_to(...)
    user_id = versions.where_object_changes_to(...).last&.whodunnit

    user_id && User.find(user_id)
  end

end
