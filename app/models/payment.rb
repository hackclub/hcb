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
#  index_payments_on_payout      (payout_type,payout_id)
#
class Payment < ApplicationRecord
  self.ignored_columns += ["payout_type", "payout_id", "failed_at"]

  include AASM
  include Receiptable
  has_paper_trail

  belongs_to :payee
  belongs_to :creator, class_name: "User"

  has_one :event, through: :payee
  has_many :attempts, class_name: "Payment::Attempt"

  monetize :amount_cents, with_model_currency: :currency

  aasm timestamps: true do
    state :pending_legal_entity, initial: true # We're waiting on the LE to complete tasks before payment can be sent
    state :under_review # HCB reviewing the underlying transfer
    state :sent
    state :successful
    state :rejected

    event :mark_under_review do
      transitions from: :pending_legal_entity, to: :under_review
    end

    event :mark_sent do
      transitions from: :under_review, to: :sent
      after do
        PaymentMailer.with(payment: self).sent.deliver_later
      end
    end

    event :mark_rejected do
      transitions from: :under_review, to: :rejected
      after do
        PaymentMailer.with(payment: self).rejected.deliver_later
      end
    end

    event :mark_successful do
      transitions from: :sent, to: :successful
    end
  end

  after_create do
    if payee.legal_entity.complete? && payee.legal_entity.default_payout_method.present?
      attempts.create!(payout_method: payee.legal_entity.default_payout_method)
    elsif payee.legal_entity.complete?
      PaymentMailer.with(payment: self, initial: true).missing_payment_method.deliver_later
    else
      PaymentMailer.with(payment: self).missing_information.deliver_later
    end
  end

  def retry!
    self.with_lock do
      raise ArgumentError, "this payment was rejected" if rejected?
      raise ArgumentError, "all attempts must have failed" unless attempts.all?(&:failed?)
      raise ArgumentError, "there is no default payout method" if payee.legal_entity.default_payout_method.nil?

      attempts.create!(payout_method: payee.legal_entity.default_payout_method)
    end
  end

  def usd_amount_cents
    MoneyService.convert_to_usd(amount_cents, currency)
  end

  def receipt_required?
    true
  end

  def marked_no_or_lost_receipt_at
    nil
  end

end
