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
    include AASM
    acts_as_paranoid

    belongs_to :payment
    belongs_to :payout, polymorphic: true, optional: true
    belongs_to :payout_method, class_name: "LegalEntity::PayoutMethod"

    scope :not_failed, -> { where.not(aasm_state: "failed" ) }

    validate :other_attempts_failed
    validate :failed_successful_attempts_frozen, on: :update

    aasm timestamps: true do
      state :pending, initial: true
      state :under_review
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
          payout.receipts.each do |receipt|
            receipt.update!(receiptable: payment)
          end

          Payment::AttemptMailer.with(attempt: self).failed_creator.deliver_later
          Payment::AttemptMailer.with(attempt: self, reason:).failed_payee.deliver_later
        end
      end
    end

    after_create :create_transfer!

    private

    def create_transfer!
      payout_method = payment.payee.legal_entity.default_payout_method
      case payout_method.details
      when LegalEntity::PayoutMethod::Check
        safely do
          check = payment.event.increase_checks.build(
            memo: "Payment for \"#{payment.purpose}\"."[0...40],
            amount: payment.estimate_usd_amount_cents,
            payment_for: "Payment for \"#{payment.purpose}\".",
            recipient_name: payment.payee.preferred_name,
            recipient_email: payment.payee.email,
            address_line1: payout_method.details.address_line1,
            address_line2: payout_method.details.address_line2,
            address_city: payout_method.details.address_city,
            address_state: payout_method.details.address_state,
            address_zip: payout_method.details.address_postal_code,
            user: User.system_user
          )

          check.save!

          self.payout = check
          save!

          transfer_receipts(check.local_hcb_code)
        end
      when LegalEntity::PayoutMethod::AchTransfer
        safely do
          ach_transfer = payment.event.ach_transfers.build(
            amount: payment.estimate_usd_amount_cents,
            payment_for: "Payment for \"#{payment.purpose}\".",
            recipient_name: payment.payee.preferred_name,
            recipient_email: payment.payee.email,
            routing_number: payout_method.details.routing_number,
            account_number: payout_method.details.account_number,
            bank_name: (ColumnService.get("/institutions/#{payout_method.routing_number}")["full_name"] rescue "Bank Account"),
            creator: User.system_user
          )

          ach_transfer.save!

          self.payout = ach_transfer
          save!

          transfer_receipts(ach_transfer.local_hcb_code)
        end
      when LegalEntity::PayoutMethod::Wire
        safely do
          wire = payment.event.wires.build(
            memo: "Payment for \"#{payment.purpose}\".",
            payment_for: "Payment for #{payment.purpose}."[0...140],
            amount_cents: payment.amount_cents,
            address_line1: payout_method.details.address_line1,
            address_line2: payout_method.details.address_line2,
            address_city: payout_method.details.address_city,
            address_state: payout_method.details.address_state,
            address_postal_code: payout_method.details.address_postal_code,
            recipient_country: payout_method.details.recipient_country,
            recipient_name: payout_method.details.recipient_name.presence || payment.payee.preferred_name,
            recipient_email: payment.payee.email,
            account_number: payout_method.details.account_number,
            bic_code: payout_method.details.bic_code,
            recipient_information: payout_method.details.recipient_information.merge({
                                                                                       purpose_code: Wire.payment_payment.purpose_code_for(payout_method.details.recipient_country),
                                                                                       remittance_info: Wire.payment_remittance_info_for(payout_method.details.recipient_country),
                                                                                     }),
            currency:,
            user: User.system_user
          )

          wire.save!

          self.payout = wire
          save!

          transfer_receipts(wire.local_hcb_code)
        end
      when LegalEntity::PayoutMethod::WiseTransfer
        safely do
          wise = payment.event.wise_transfers.build(
            memo: "Payment for \"#{payment.purpose}\"",
            amount: payment.amount_cents,
            payment_for: "Payment for \"#{payment.purpose}\"",
            recipient_name: payment.payee.preferred_name,
            recipient_email: payment.payee.email,
            address_line1: payout_method.details.address_line1,
            address_line2: payout_method.details.address_line2,
            address_city: payout_method.details.address_city,
            address_state: payout_method.details.address_state,
            address_postal_code: payout_method.details.address_postal_code,
            recipient_country: payout_method.details.recipient_country,
            bank_name: payout_method.details.bank_name,
            recipient_information: payout_method.details.recipient_information,
            currency:,
            user: User.system_user
          )

          wise.save!

          self.payout = wise
          save!

          transfer_receipts(wise.local_hcb_code)
        end
      else
        raise ArgumentError, "🚨⚠️ unsupported payout method!"
      end

      mark_under_review!
    end

    def transfer_receipts(hcb_code)
      payment.receipts.each do |receipt|
        receipt.update!(receiptable: hcb_code)
      end
    end

    def other_attempts_failed
      if Payment::Attempt.not_failed.where(payment:).excluding(self).any?
        errors.add(:base, "all other attempts for this payment must be failed before creating a new attempt")
      end
    end

    def failed_successful_attempts_frozen
      if (failed? || successful?) && !aasm_state_changed?
        errors.add(:base, "failed or successful payment attempts cannot be updated")
      end
    end

  end

end
