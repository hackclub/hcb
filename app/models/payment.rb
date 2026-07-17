# frozen_string_literal: true

# == Schema Information
#
# Table name: payments
#
#  id              :bigint           not null, primary key
#  aasm_state      :string           not null
#  amount_cents    :integer          not null
#  currency        :string           not null
#  purpose         :string           not null
#  rejected_at     :datetime
#  sent_at         :datetime
#  successful_at   :datetime
#  tax_reportable  :boolean          default(TRUE), not null
#  under_review_at :datetime
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  creator_id      :bigint           not null
#  payee_id        :bigint           not null
#
# Indexes
#
#  index_payments_on_creator_id  (creator_id)
#  index_payments_on_payee_id    (payee_id)
#
class Payment < ApplicationRecord
  TAX_FORM_MINIMUM_CENTS = 500_00

  include AASM
  include Hashid::Rails
  include PgSearch::Model
  include Receiptable
  include Commentable
  has_paper_trail

  belongs_to :payee
  belongs_to :creator, class_name: "User"

  has_one :event, through: :payee
  has_one :legal_entity, through: :payee
  has_many :attempts, -> { order(created_at: :desc) }, class_name: "Payment::Attempt", inverse_of: :payment
  has_one :successful_attempt, -> { successful }, class_name: "Payment::Attempt", inverse_of: :payment
  has_one :current_attempt, -> { not_failed }, class_name: "Payment::Attempt", inverse_of: :payment
  has_one :payroll_invoice, class_name: "Payroll::Invoice", inverse_of: :payment, dependent: :nullify

  monetize :amount_cents, with_model_currency: :currency

  pg_search_scope :search_recipient, associated_against: { payee: [:display_name, :email] }
  pg_search_scope :search_purpose_and_event, against: [:purpose], associated_against: { event: [:name] }

  scope :successful_or_sent, -> { where(aasm_state: ["successful", "sent"]) }
  scope :pending_or_under_review, -> { where(aasm_state: ["pending_legal_entity", "under_review"]) }

  aasm timestamps: true do
    state :pending_legal_entity, initial: true # We're waiting on the LE to complete tasks before payment can be sent
    state :under_review # HCB reviewing the underlying transfer
    state :sent
    state :successful
    state :rejected
    state :canceled

    event :mark_under_review do
      transitions from: [:pending_legal_entity, :sent], to: :under_review
    end

    event :mark_sent do
      transitions from: :under_review, to: :sent
      after do
        PaymentMailer.with(payment: self).sent.deliver_later
      end
    end

    event :mark_rejected do
      transitions from: :under_review, to: :rejected
    end

    event :mark_successful do
      transitions from: :sent, to: :successful
    end

    event :mark_canceled do
      transitions from: [:pending_legal_entity, :under_review, :sent], to: :canceled
      after do
        current_attempt&.mark_canceled!
      end
    end
  end

  after_create do
    payable = legal_entity&.payable?(requires_tax_form: requires_tax_form?)

    if payable && legal_entity.default_payout_method.present?
      create_payment_attempt!
    elsif payable
      PaymentMailer.with(payment: self, initial: true).missing_payout_method.deliver_later
    else
      PaymentMailer.with(payment: self).missing_tax_information.deliver_later
    end
  end

  def retry!
    create_payment_attempt!
  end

  def payout
    attempts.first&.payout
  end

  def popover_path
    Rails.application.routes.url_helpers.payment_path(id: hashid, frame: true)
  end

  def estimate_usd_amount_cents
    MoneyService.convert_to_usd(amount_cents, currency)
  end

  # Payments that aren't tax reportable, or too small to move the needle,
  # don't need to wait on the payee's tax paperwork.
  def requires_tax_form?
    tax_reportable? && estimate_usd_amount_cents >= TAX_FORM_MINIMUM_CENTS
  end

  def on_legal_entity_assigned
    on_legal_entity_payable if legal_entity.payable?(requires_tax_form: requires_tax_form?)
  end

  def on_legal_entity_payable
    if legal_entity.default_payout_method.present?
      create_payment_attempt!
    else
      PaymentMailer.with(payment: self, initial: false).missing_payout_method.deliver_later
    end
  end

  def on_default_payout_method_created
    create_payment_attempt! if legal_entity.payable?(requires_tax_form: requires_tax_form?)
  end

  def receipt_required?
    true
  end

  def marked_no_or_lost_receipt_at
    nil
  end


  def state_color
    return "warning" if ["under_review", "pending_legal_entity"].include?(aasm_state)
    return "success" if aasm_state == "successful"
    return "error" if aasm_state == "rejected"

    "muted"
  end

  def state_text
    return "Awaiting recipient" if pending_legal_entity?
    return "Processing" if under_review?

    return aasm_state.humanize
  end

  def memo
    "Payment to #{payee.display_name} for #{purpose}"
  end

  private

  def create_payment_attempt!
    self.with_lock do
      raise ArgumentError, "this payment was rejected" if rejected?
      raise ArgumentError, "all attempts must have failed" unless attempts.all?(&:failed?)
      raise ArgumentError, "there is no default payout method" if legal_entity.default_payout_method.nil?

      attempts.create!(payout_method: legal_entity.default_payout_method)
    end
  end

end
