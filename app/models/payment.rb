# frozen_string_literal: true

# == Schema Information
#
# Table name: payments
#
#  id              :bigint           not null, primary key
#  aasm_state      :string           not null
#  amount_cents    :integer          not null
#  failed_at       :datetime
#  payout_type     :string
#  purpose         :string           not null
#  rejected_at     :datetime
#  sent_at         :datetime
#  successful_at   :datetime
#  under_review_at :datetime
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  creator_id      :bigint           not null
#  payee_id        :bigint           not null
#  payout_id       :bigint
#
# Indexes
#
#  index_payments_on_creator_id  (creator_id)
#  index_payments_on_payee_id    (payee_id)
#  index_payments_on_payout      (payout_type,payout_id)
#
class Payment < ApplicationRecord
  include AASM
  include Receiptable
  has_paper_trail

  belongs_to :payout, polymorphic: true, optional: true
  belongs_to :payee
  belongs_to :creator, class_name: "User"

  has_one :event, through: :payee

  monetize :amount_cents

  aasm timestamps: true do
    state :pending_legal_entity, initial: true # We're waiting on the LE to complete tasks before payment can be sent
    state :under_review # HCB reviewing the underlying transfer
    state :sent
    state :rejected
    state :failed
    state :successful

    event :mark_under_review do
      transitions from: :pending_legal_entity, to: :under_review, if: -> { payee.legal_entity.complete? && payee.legal_entity.default_payment_method.present? }
      after do
        create_transfer!
      end
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

    event :mark_failed do
      transitions from: [:sent, :successful], to: :failed
      after do |reason: nil|
        PaymentMailer.with(payment: self).failed_creator.deliver_later
        PaymentMailer.with(payment: self, reason:).failed_payee.deliver_later
      end
    end

    event :mark_successful do
      transitions from: :sent, to: :successful
    end
  end

  after_create do
    if may_mark_under_review?
      mark_under_review!
    elsif payee.legal_entity.complete?
      PaymentMailer.with(payment: self, initial: true).missing_payment_method.deliver_later
    else
      PaymentMailer.with(payment: self).missing_information.deliver_later
    end
  end

  def receipt_required?
    true
  end

  def marked_no_or_lost_receipt_at
    nil
  end

  private

  def create_transfer!
    # actually send
  end

end
