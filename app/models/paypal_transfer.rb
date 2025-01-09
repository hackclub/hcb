# frozen_string_literal: true

# == Schema Information
#
# Table name: paypal_transfers
#
#  id              :bigint           not null, primary key
#  aasm_state      :string           not null
#  amount_cents    :integer          not null
#  approved_at     :datetime
#  memo            :string           not null
#  payment_for     :string           not null
#  recipient_email :string           not null
#  recipient_name  :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  event_id        :bigint           not null
#  user_id         :bigint           not null
#
# Indexes
#
#  index_paypal_transfers_on_event_id  (event_id)
#  index_paypal_transfers_on_user_id   (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#  fk_rails_...  (user_id => users.id)
#
class PaypalTransfer < ApplicationRecord
  has_paper_trail

  include PgSearch::Model
  pg_search_scope :search_recipient, against: [:recipient_name, :recipient_email]

  include AASM

  belongs_to :event
  belongs_to :user

  has_one :canonical_pending_transaction
  has_one :reimbursement_payout_holding, class_name: "Reimbursement::PayoutHolding", inverse_of: :paypal_transfer, required: false

  monetize :amount_cents, as: "amount"

  include PublicActivity::Model
  tracked owner: proc{ |controller, record| controller&.current_user }, event_id: proc { |controller, record| record.event.id }, only: [:create]

  validate on: :create do
    errors.add(:base, "Due to integration issues, transfers via PayPal are currently unavailable.")
  end

  after_create do
    create_canonical_pending_transaction!(event:, amount_cents: -amount_cents, memo: "PayPal transfer to #{recipient_name}".strip.upcase, date: created_at)
  end

  aasm timestamps: true, whiny_persistence: true do
    state :pending, initial: true
    state :approved
    state :rejected
    state :failed
    state :deposited

    event :mark_approved do
      transitions from: :pending, to: :approved
    end

    event :mark_rejected do
      transitions from: :pending, to: :rejected do
        guard do
          reimbursement_payout_holding.nil? # these should be marked as failed.
        end
      end
      after do
        canonical_pending_transaction.decline!
        create_activity(key: "paypal_transfer.rejected")
      end
    end

    event :mark_failed do
      transitions from: [:pending, :approved], to: :failed
      after do
        canonical_pending_transaction.decline!
        create_activity(key: "paypal_transfer.failed")
        if reimbursement_payout_holding.present?
          ReimbursementMailer.with(reimbursement_payout_holding:).paypal_transfer_failed.deliver_later
          reimbursement_payout_holding.mark_failed!
        end
      end
    end

    event :mark_deposited do
      transitions from: :approved, to: :deposited
    end
  end

  validates :amount_cents, numericality: { greater_than: 0, message: "must be positive!" }

  validates :recipient_email, format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" }

  validates_presence_of :memo, :payment_for, :recipient_name, :recipient_email

  validate on: :create do
    if amount_cents > event.balance_available_v2_cents
      errors.add(:base, "You don't have enough money to send this transfer! Your balance is #{(event.balance_available_v2_cents / 100).to_money.format}.")
    end
  end

  def state
    if pending?
      :muted
    elsif rejected?
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
    "HCB-#{TransactionGroupingEngine::Calculate::HcbCode::PAYPAL_TRANSFER_CODE}-#{id}"
  end

  def admin_dropdown_description
    "#{ApplicationController.helpers.render_money(amount_cents)} to #{recipient_email} from #{event.name}"
  end

  def local_hcb_code
    @local_hcb_code ||= HcbCode.find_or_create_by(hcb_code:)
  end

end
