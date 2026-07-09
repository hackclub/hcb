# frozen_string_literal: true

# == Schema Information
#
# Table name: payment_attempts
#
#  id               :bigint           not null, primary key
#  aasm_state       :string           not null
#  deleted_at       :datetime
#  failed_at        :datetime
#  payout_type      :string
#  sent_at          :datetime
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  payment_id       :bigint           not null
#  payout_id        :bigint
#  payout_method_id :bigint           not null
#
# Indexes
#
#  index_payment_attempts_on_payment_id        (payment_id)
#  index_payment_attempts_on_payout            (payout_type,payout_id)
#  index_payment_attempts_on_payout_method_id  (payout_method_id)
#
class Payment
  class Attempt < ApplicationRecord
    PAYOUT_METHOD_TRANSFER_MAPPING = {
      LegalEntity::PayoutMethod::Check        => IncreaseCheck,
      LegalEntity::PayoutMethod::AchTransfer  => AchTransfer,
      LegalEntity::PayoutMethod::Wire         => Wire,
      LegalEntity::PayoutMethod::WiseTransfer => WiseTransfer
    }.freeze

    include AASM
    acts_as_paranoid

    belongs_to :payment
    belongs_to :payout, polymorphic: true, optional: true
    belongs_to :payout_method, class_name: "LegalEntity::PayoutMethod"

    has_one :legal_entity, through: :payment

    scope :not_failed, -> { where.not(aasm_state: "failed" ) }

    validate :other_attempts_failed
    validate :terminal_states_freeze_attempt, on: :update
    validate :transfer_matches_payout_method
    validate :legal_entity_payable, on: :create

    aasm timestamps: true do
      state :pending, initial: true
      state :under_review
      state :rejected
      state :sent
      state :successful
      state :failed

      event :mark_under_review do
        transitions from: :pending, to: :under_review, if: -> { payout.present? }
        after do
          payment.mark_under_review!
        end
      end

      event :mark_sent do
        transitions from: :under_review, to: :sent
        after do
          payment.mark_sent!
        end
      end

      event :mark_successful do
        transitions from: :sent, to: :successful
        after do
          payment.mark_successful!
        end
      end

      event :mark_failed do
        transitions from: :sent, to: :failed
        after do |reason: nil|
          Payment::AttemptMailer.with(attempt: self).failed_creator.deliver_later
          Payment::AttemptMailer.with(attempt: self, reason:).failed_payee.deliver_later
        end
      end

      event :mark_rejected do
        transitions from: :under_review, to: :rejected
        after do
          payment.mark_rejected!
        end
      end
    end

    after_create :create_transfer!

    private

    def create_transfer!
      self.with_lock do
        payout_method = legal_entity.default_payout_method
        unless PAYOUT_METHOD_TRANSFER_MAPPING.key?(payout_method.details.class)
          raise ArgumentError, "🚨⚠️ unsupported payout method!"
        end

        safely do
          transfer = payout_method.create_transfer(
            payment.event,
            amount: payment.amount_cents,
            memo: "Payment for \"#{payment.purpose}\".",
            payment_for: "Payment for \"#{payment.purpose}\".",
            recipient_name: payment.payee.display_name,
            recipient_email: payment.payee.email,
            currency: payment.currency,
            user: payment.creator,
          )

          transfer.save!

          self.payout = transfer
          save!

          Receipt.reupload(old_receiptable: payment, new_receiptable: transfer.local_hcb_code)
        end

        mark_under_review!
      end
    end

    def other_attempts_failed
      if Payment::Attempt.not_failed.where(payment:).excluding(self).any?
        errors.add(:base, "all other attempts for this payment must be failed before creating a new attempt")
      end
    end

    def terminal_states_freeze_attempt
      if (failed? || successful? || rejected?) && !aasm_state_changed?
        errors.add(:base, "failed, successful, or rejected payment attempts cannot be updated")
      end
    end

    def transfer_matches_payout_method
      if payout.present? && PAYOUT_METHOD_TRANSFER_MAPPING[payout_method.details.class] != payout.class
        errors.add(:base, "transfer type must match payout method")
      end
    end

    def legal_entity_payable
      unless legal_entity.payable?
        errors.add(:legal_entity, "must be payable")
      end
    end

  end

end
