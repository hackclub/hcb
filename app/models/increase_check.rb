# frozen_string_literal: true

# == Schema Information
#
# Table name: increase_checks
#
#  id                      :bigint           not null, primary key
#  aasm_state              :string
#  address_city            :string
#  address_line1           :string
#  address_line2           :string
#  address_state           :string
#  address_zip             :string
#  amount                  :integer
#  approved_at             :datetime
#  check_number            :string
#  column_delivery_status  :string
#  column_object           :jsonb
#  column_status           :string
#  increase_object         :jsonb
#  increase_status         :string
#  memo                    :string
#  payment_for             :string
#  recipient_email         :string
#  recipient_name          :string
#  send_email_notification :boolean          default(FALSE)
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  column_id               :string
#  event_id                :bigint           not null
#  increase_id             :string
#  user_id                 :bigint
#
# Indexes
#
#  index_increase_checks_on_column_id       (column_id) UNIQUE
#  index_increase_checks_on_event_id        (event_id)
#  index_increase_checks_on_transaction_id  ((((increase_object -> 'deposit'::text) ->> 'transaction_id'::text)))
#  index_increase_checks_on_user_id         (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#  fk_rails_...  (user_id => users.id)
#
class IncreaseCheck < ApplicationRecord
  # [@garyhtou] `IncreaseCheck` superseded `Check` starting March 2023.
  # On January 2024, we switched check printing & mailing services from
  # Increase to Column. This model, although still named `IncreaseCheck`, now
  # handles Column check transfers.
  has_paper_trail

  self.ignored_columns = ["increase_state"]

  include AASM

  include PgSearch::Model
  pg_search_scope :search_recipient, against: [:recipient_name, :memo], using: { tsearch: { prefix: true, dictionary: "english" } }, ranked_by: "increase_checks.created_at"

  include PublicActivity::Model
  tracked owner: proc{ |controller, record| controller&.current_user }, event_id: proc { |controller, record| record.event.id }, only: [:create]

  belongs_to :event
  belongs_to :user, optional: true

  has_one :canonical_pending_transaction
  has_one :grant, required: false
  has_one :reimbursement_payout_holding, class_name: "Reimbursement::PayoutHolding", inverse_of: :increase_check, required: false

  after_create do
    create_canonical_pending_transaction!(event:, amount_cents: -amount, memo: "OUTGOING CHECK", date: created_at)
  end

  after_update if: -> { column_status_previously_changed?(to: "stopped") } do
    canonical_pending_transaction.decline!
  end

  aasm timestamps: true, whiny_persistence: true do
    state :pending, initial: true
    state :approved
    state :rejected

    event :mark_approved do
      after do
        if self.send_email_notification
          IncreaseCheckJob::RemindUndepositedRecipient.set(wait: 30.days).perform_later(self)
          IncreaseCheckJob::RemindUndepositedRecipient.set(wait: (180 - 30).days).perform_later(self)
        end

        canonical_pending_transaction.update(fronted: true)
      end
      transitions from: :pending, to: :approved

      after_commit do
        IncreaseCheckMailer.with(check: self).notify_recipient.deliver_later
      end
    end

    event :mark_rejected do
      after do
        canonical_pending_transaction.decline!
        create_activity(key: "increase_check.rejected")
      end
      transitions from: :pending, to: :rejected
    end
  end

  validates :amount, numericality: { greater_than: 0, message: "can't be zero!" }
  validates :memo, length: { in: 1..40 }, on: :create
  validates :recipient_name, length: { in: 1..250 }
  validates_presence_of :memo, :payment_for, :recipient_name, :address_line1, :address_city, :address_zip
  validates_presence_of :address_state, message: "Please select a state!"
  validates :address_state, inclusion: { in: ["AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "DC", "FL", "GA", "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD", "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ", "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC", "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY"], message: "This isn't a valid US state!", allow_blank: true }
  validates :address_zip, format: { with: /\A\d{5}(?:[-\s]\d{4})?\z/, message: "This isn't a valid ZIP code." }

  validates :recipient_email, format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" }, allow_nil: true
  validates_presence_of :recipient_email, on: :create
  normalizes :recipient_email, with: ->(recipient_email) { recipient_email.strip.downcase }

  validate on: :create do
    if amount > event.balance_available_v2_cents
      errors.add(:amount, "You don't have enough money to send this transfer! Your balance is #{ApplicationController.helpers.render_money(event.balance_available_v2_cents)}.")
    end
  end

  validate do
    if (address_line1.length + address_line2.length) > 50
      errors.add(:base, "Address line one and line two's combined length can not exceed 50 characters.")
    end
  end

  scope :in_transit, -> { where(increase_status: [:pending_submission, :submitting, :submitted, :pending_mailing, :mailed]) }
  scope :canceled, -> { where(increase_status: [:rejected, :canceled, :stopped, :returned, :rejected]).or(where(aasm_state: :rejected)) }

  enum :increase_status, {
    pending_approval: "pending_approval",
    pending_submission: "pending_submission",
    submitting: "submitting",
    submitted: "submitted",
    pending_mailing: "pending_mailing",
    mailed: "mailed",
    canceled: "canceled",
    deposited: "deposited",
    stopped: "stopped",
    returned: "returned",
    rejected: "rejected",
    requires_attention: "requires_attention"
  }, prefix: :increase

  enum :column_status, %w(initiated issued manual_review rejected pending_deposit pending_stop deposited stopped pending_first_return pending_second_return first_return pending_reclear recleared second_return settled returned pending_user_initiated_return user_initiated_return_submitted user_initiated_returned pending_user_initiated_return_dishonored).index_with(&:itself), prefix: :column
  enum :column_delivery_status, %w(created mailed in_transit in_local_area processed_for_delivery delivered failed rerouted returned_to_sender).index_with(&:itself), prefix: :column_delivery

  VALID_DURATION = 180.days

  def column?
    column_id.present?
  end

  def increase?
    increase_id.present?
  end

  def state
    if column?
      :info
    elsif pending?
      :muted
    elsif rejected? || increase_canceled? || increase_stopped? || increase_returned? || increase_rejected?
      :error
    elsif increase_deposited?
      :success
    else
      :info
    end
  end

  def state_text
    if column?
      column_status.humanize
    elsif pending?
      "Pending approval"
    elsif rejected?
      "Rejected"
    elsif increase_pending_submission? || increase_submitting? || increase_submitted? || increase_pending_mailing?
      "Processing"
    elsif increase_mailed?
      "On the way"
    elsif increase_deposited?
      "Deposited"
    elsif increase_canceled? || increase_stopped?
      "Canceled"
    elsif increase_returned?
      "Returned"
    else
      "Unknown status"
    end
  end

  alias_attribute :name, :recipient_name

  def hcb_code
    "HCB-#{TransactionGroupingEngine::Calculate::HcbCode::INCREASE_CHECK_CODE}-#{id}"
  end

  def local_hcb_code
    @local_hcb_code ||= HcbCode.find_or_create_by(hcb_code:)
  end

  def sent?
    approved?
  end

  def address
    "#{address_line1} #{address_line2} - #{address_city}, #{address_state} #{address_zip}"
  end

  def send_check!
    return unless may_mark_approved?

    if Flipper.enabled?(:column_check_transfers, event)
      send_column!
    else
      send_increase!
    end

    mark_approved!

    if grant.present?
      grant.mark_fulfilled!
    end
  end

  private

  def send_increase!
    increase_check = Increase::CheckTransfers.create(
      account_id: IncreaseService::AccountIds::FS_MAIN,
      source_account_number_id: event.increase_account_number_id,
      # Increase will print and mail the physical check for us
      fulfillment_method: "physical_check",
      physical_check: {
        memo:,
        note: "Check from #{event.name}",
        recipient_name:,
        mailing_address: {
          line1: address_line1,
          line2: address_line2.presence,
          city: address_city,
          state: address_state,
          postal_code: address_zip,
        }
      },
      unique_identifier: self.id.to_s,
      amount:,
    )

    update!(increase_id: increase_check["id"], increase_status: increase_check["status"])
  end

  def send_column!
    account_number_id = event.column_account_number&.column_id ||
                        Rails.application.credentials.dig(:column, ColumnService::ENVIRONMENT, :default_account_number)

    column_check = ColumnService.post "/transfers/checks/issue",
                                      idempotency_key: self.id.to_s,
                                      account_number_id:,
                                      positive_pay_amount: amount,
                                      currency_code: "USD",
                                      payee_name: recipient_name,
                                      mail_check_request: {
                                        message: "Check from #{event.name}",
                                        memo:,
                                        payee_address: {
                                          line_1: address_line1,
                                          line_2: address_line2,
                                          city: address_city,
                                          state: address_state,
                                          postal_code: address_zip,
                                          country_code: "US",
                                        }.compact_blank,
                                        payor_name: event.short_name(length: 40),
                                        payor_address: {
                                          line_1: "8605 Santa Monica Blvd #86294",
                                          city: "West Hollywood",
                                          state: "CA",
                                          postal_code: "90069",
                                          country_code: "US",
                                        },
                                      }

    update!(
      column_id: column_check["id"],
      column_object: column_check,
      check_number: column_check["check_number"],
      column_status: column_check["status"],
      column_delivery_status: column_check["delivery_status"],
    )
  end

end
