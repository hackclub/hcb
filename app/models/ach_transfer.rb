# frozen_string_literal: true

# == Schema Information
#
# Table name: ach_transfers
#
#  id                        :bigint           not null, primary key
#  aasm_state                :string
#  account_number_bidx       :string
#  account_number_ciphertext :text
#  amount                    :integer
#  approved_at               :datetime
#  bank_name                 :string
#  company_entry_description :string
#  company_name              :string
#  confirmation_number       :text
#  payment_for               :text
#  recipient_email           :string
#  recipient_name            :string
#  recipient_tel             :string
#  rejected_at               :datetime
#  routing_number_bidx       :string
#  routing_number_ciphertext :text
#  same_day                  :boolean          default(FALSE), not null
#  scheduled_arrival_date    :datetime
#  scheduled_on              :date
#  send_email_notification   :boolean          default(FALSE)
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  column_id                 :text
#  creator_id                :bigint
#  event_id                  :bigint
#  increase_id               :text
#  payment_recipient_id      :bigint
#  processor_id              :bigint
#
# Indexes
#
#  index_ach_transfers_on_account_number_bidx   (account_number_bidx)
#  index_ach_transfers_on_column_id             (column_id) UNIQUE
#  index_ach_transfers_on_creator_id            (creator_id)
#  index_ach_transfers_on_event_id              (event_id)
#  index_ach_transfers_on_increase_id           (increase_id) UNIQUE
#  index_ach_transfers_on_payment_recipient_id  (payment_recipient_id)
#  index_ach_transfers_on_processor_id          (processor_id)
#  index_ach_transfers_on_routing_number_bidx   (routing_number_bidx)
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (event_id => events.id)
#
class AchTransfer < ApplicationRecord
  has_paper_trail skip: [:account_number, :routing_index] # ciphertext columns will still be tracked
  has_encrypted :account_number
  blind_index :account_number
  has_encrypted :routing_number
  blind_index :routing_number
  monetize :amount, as: "amount_money"

  include PublicIdentifiable
  set_public_id_prefix :ach

  include AASM
  include Commentable
  include Payoutable
  include Payment
  include Freezable

  def payment_recipient_attributes
    %i[bank_name account_number routing_number]
  end

  include PgSearch::Model
  pg_search_scope :search_recipient, against: [:recipient_name], using: { tsearch: { prefix: true, dictionary: "english" } }, ranked_by: "ach_transfers.created_at"

  include PublicActivity::Model
  tracked owner: proc{ |controller, record| controller&.current_user }, event_id: proc { |controller, record| record.event.id }, only: [:create]

  belongs_to :creator, class_name: "User", optional: true
  belongs_to :processor, class_name: "User", optional: true
  belongs_to :event

  validates :amount, numericality: { greater_than: 0, message: "must be greater than 0" }

  validates :routing_number, presence: true, unless: :payment_recipient
  validates :account_number, presence: true, unless: :payment_recipient
  validates :recipient_name, presence: true, unless: :payment_recipient

  validates :account_number, format: { with: /\A\d+\z/, message: "must be only numbers" }, allow_blank: true
  validates :routing_number, format: { with: /\A\d{9}\z/, message: "must be 9 digits" }, allow_blank: true
  validates :bank_name, presence: true, on: :create, unless: :payment_recipient

  validates :recipient_email, format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" }, allow_nil: true
  normalizes :recipient_email, with: ->(recipient_email) { recipient_email.strip.downcase }
  validates_presence_of :recipient_email, on: :create
  validate :scheduled_on_must_be_in_the_future, on: :create
  validate on: :create do
    if amount > event.balance_available_v2_cents
      errors.add(:base, "You don't have enough money to send this transfer! Your balance is #{(event.balance_available_v2_cents / 100).to_money.format}.")
    end
  end
  validates :company_entry_description, length: { maximum: 10 }, allow_blank: true
  validates :company_name, length: { maximum: 16 }, allow_blank: true

  has_one :t_transaction, class_name: "Transaction", inverse_of: :ach_transfer
  has_one :raw_pending_outgoing_ach_transaction, foreign_key: :ach_transaction_id
  has_one :canonical_pending_transaction, through: :raw_pending_outgoing_ach_transaction
  has_one :employee_payment, class_name: "Employee::Payment", as: :payout
  has_one :reimbursement_payout_holding, class_name: "Reimbursement::PayoutHolding", inverse_of: :ach_transfer, required: false

  has_one :raw_pending_outgoing_ach_transaction, foreign_key: :ach_transaction_id
  has_one :canonical_pending_transaction, through: :raw_pending_outgoing_ach_transaction

  scope :scheduled_for_today, -> { scheduled.where(scheduled_on: ..Date.today) }

  scope :realtime, -> { where("column_id ILIKE 'rttr%'") }

  after_initialize do
    self.same_day = true
  end

  aasm whiny_persistence: true do
    state :pending, initial: true
    state :scheduled
    state :in_transit
    state :rejected
    state :failed
    state :deposited

    event :mark_in_transit do
      after do
        AchTransferMailer.with(ach_transfer: self).notify_recipient.deliver_later if self.send_email_notification
        employee_payment.mark_paid! if employee_payment.present?
      end
      transitions from: [:pending, :deposited, :scheduled], to: :in_transit
    end

    event :mark_rejected do
      after do |processed_by = nil|
        canonical_pending_transaction&.decline!
        update!(processor: processed_by) if processed_by.present?
        create_activity(key: "ach_transfer.rejected", owner: processed_by)
        employee_payment&.mark_rejected!(send_email: false) # Operations will manually reach out
      end
      transitions from: [:pending, :scheduled], to: :rejected
    end

    event :mark_deposited do
      transitions from: :in_transit, to: :deposited
    end

    event :mark_scheduled do
      transitions from: :pending, to: :scheduled
    end

    event :mark_failed do
      after do |reason: nil|
        if reimbursement_payout_holding.present?
          ReimbursementMailer.with(reimbursement_payout_holding:, reason:).ach_failed.deliver_later
          reimbursement_payout_holding.mark_failed!
        elsif employee_payment.present?
          employee_payment.mark_failed!(reason:)
        else
          AchTransferMailer.with(ach_transfer: self, reason:).notify_failed.deliver_later
        end
        create_activity(key: "ach_transfer.failed", owner: nil)
      end
      transitions from: [:in_transit, :deposited], to: :failed
    end
  end

  before_validation { self.recipient_name = recipient_name.presence&.strip }

  before_validation do
    self.company_name = event.short_name if company_name.blank?
  end

  # Eagerly create HcbCode object
  after_create :local_hcb_code

  after_create unless: -> { scheduled_on.present? } do
    create_raw_pending_outgoing_ach_transaction!(amount_cents: -amount, date_posted: scheduled_on || created_at)
    raw_pending_outgoing_ach_transaction.create_canonical_pending_transaction!(
      event:,
      amount_cents: -amount,
      memo: raw_pending_outgoing_ach_transaction.memo,
      date: raw_pending_outgoing_ach_transaction.date_posted,
    )
  end

  def send_ach_transfer!
    return unless may_mark_in_transit?

    account_number_id = event.column_account_number&.column_id ||
                        Credentials.fetch(:COLUMN, ColumnService::ENVIRONMENT, :DEFAULT_ACCOUNT_NUMBER)

    column_ach_transfer = ColumnService.post("/transfers/ach", {
      idempotency_key: self.id.to_s,
      amount:,
      currency_code: "USD",
      type: "CREDIT",
      entry_class_code: "PPD",
      counterparty: {
        account_number:,
        routing_number:,
      },
      company_name:,
      company_entry_description:,
      description: payment_for,
      account_number_id:,
      same_day:,
    }.compact_blank)

    mark_in_transit
    self.column_id = column_ach_transfer["id"]

    save!
  end

  def send_realtime_transfer!
    return unless may_mark_in_transit?

    account_number_id = (event.column_account_number || event.create_column_account_number)&.column_id

    column_counterparty = ColumnService.post("/counterparties", {
      idempotency_key: self.id.to_s,
      account_number:,
      routing_number:
    }.compact_blank)

    column_realtime_transfer = ColumnService.post("/transfers/realtime", {
      idempotency_key: self.id.to_s,
      amount:,
      currency_code: "USD",
      counterparty_id: column_counterparty["id"],
      description: payment_for,
      account_number_id:,
    }.compact_blank)

    mark_in_transit
    self.column_id = column_realtime_transfer["id"]

    save!
  end

  def realtime?
    column_id&.starts_with?("rttr")
  end

  # reason must be listed on https://column.com/docs/api/#ach-transfer/reverse
  def reverse!(reason)
    raise ArgumentError, "must have been sent" unless column_id

    ColumnService.post "/transfers/ach/#{column_id}/reverse", reason:, idempotency_key: self.id.to_s
  end

  def pending_expired?
    local_hcb_code.has_pending_expired?
  end

  def approve!(processed_by = nil, send_realtime: false)
    if scheduled_on.present?
      mark_scheduled!
    elsif send_realtime
      send_realtime_transfer!
    else
      send_ach_transfer!
    end

    update!(processor: processed_by) if processed_by.present?
  end

  def status
    aasm.current_state
  end

  alias_attribute :name, :recipient_name

  def status_text
    aasm.human_state
  end

  alias_method :state_text, :status_text

  def status_text_long
    case status
    when :deposited then "Deposited successfully"
    when :scheduled then "Scheduled for #{scheduled_on.strftime("%B %-d, %Y")}"
    when :in_transit then "In transit"
    when :pending then "Waiting on HCB approval"
    when :rejected then "Rejected"
    else status_text
    end
  end

  def state
    case status
    when :deposited then :success
    when :in_transit then :info
    when :scheduled then :pending
    when :pending then :pending
    when :rejected then :error
    when :failed then :error
    end
  end

  def state_icon
    "checkmark" if deposited?
  end

  def approved?
    !pending?
  end

  def admin_dropdown_description
    "#{event.name} - #{recipient_name} | #{ApplicationController.helpers.render_money amount}"
  end

  def smart_memo
    recipient_name.to_s.upcase
  end

  def canonical_transactions
    @canonical_transactions ||= CanonicalTransaction.where(hcb_code:)
  end

  def hcb_code
    "HCB-#{TransactionGroupingEngine::Calculate::HcbCode::ACH_TRANSFER_CODE}-#{id}"
  end

  def local_hcb_code
    @local_hcb_code ||= HcbCode.find_or_create_by(hcb_code:)
  end

  def estimated_arrival
    # https://column.com/docs/ach/timing

    now = ActiveSupport::TimeZone.new("America/Los_Angeles").now

    return now if realtime?

    if same_day? && now.workday?
      return now.change(hour: 10, minute: 0, second: 0) if now < now.change(hour: 7, min: 15, sec: 0)
      return now.change(hour: 14, minute: 0, second: 0) if now < now.change(hour: 11, min: 30, sec: 0)
      return now.change(hour: 15, minute: 0, second: 0) if now < now.change(hour: 13, min: 30, sec: 0)
    end

    return 0.business_days.after(now).change(hour: 5, min: 30, sec: 0) unless now.workday?

    return 1.business_day.after(now).change(hour: 5, min: 30, sec: 0)
  end

  private

  def scheduled_on_must_be_in_the_future
    if scheduled_on.present? && scheduled_on.before?(Date.today)
      errors.add(:scheduled_on, "must be in the future")
    end
  end

end
