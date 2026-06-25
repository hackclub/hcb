# frozen_string_literal: true

# == Schema Information
#
# Table name: payments
#
#  id              :bigint           not null, primary key
#  aasm_state      :string           not null
#  amount_cents    :integer          not null
#  currency        :string           not null
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

  monetize :amount_cents, with_model_currency: :currency

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
    payout_method = payee.legal_entity.default_payout_method
    case payout_method
    when User::PayoutMethod::Check
      safely do
        check = event.increase_checks.build(
          memo: "Payment for \"#{purpose}\"."[0...40],
          amount: amount_cents,
          payment_for: "Payment for \"#{purpose}\".",
          recipient_name: payee.preferred_name,
          address_line1: payout_method.address_line1,
          address_line2: payout_method.address_line2,
          address_city: payout_method.address_city,
          address_state: payout_method.address_state,
          address_zip: payout_method.address_postal_code,
          user: User.system_user
        )

        check.save!

        self.payout = check
        save!

        transfer_receipts(check.local_hcb_code)
      end
    when User::PayoutMethod::AchTransfer
      safely do
        ach_transfer = event.ach_transfers.build(
          amount: amount_cents,
          payment_for: "Payment for \"#{purpose}\".",
          recipient_name: payee.preferred_name,
          routing_number: payout_method.routing_number,
          account_number: payout_method.account_number,
          bank_name: (ColumnService.get("/institutions/#{payout_method.routing_number}")["full_name"] rescue "Bank Account"),
          creator: User.system_user
        )

        ach_transfer.save!

        self.payout = ach_transfer
        save!

        transfer_receipts(ach_transfer.local_hcb_code)
      end
    when User::PayoutMethod::Wire
      safely do
        wire = event.wires.build(
          memo: "Payment for \"#{purpose}\".",
          payment_for: "Payment for #{purpose}."[0...140],
          amount_cents:,
          address_line1: payout_method.address_line1,
          address_line2: payout_method.address_line2,
          address_city: payout_method.address_city,
          address_state: payout_method.address_state,
          address_postal_code: payout_method.address_postal_code,
          recipient_country: payout_method.recipient_country,
          recipient_name: payout_method.recipient_name.presence || payee.preferred_name,
          account_number: payout_method.account_number,
          bic_code: payout_method.bic_code,
          recipient_information: payout_method.recipient_information.merge({
                                                                             purpose_code: Wire.payment_purpose_code_for(payout_method.recipient_country),
                                                                             remittance_info: Wire.payment_remittance_info_for(payout_method.recipient_country),
                                                                           }),
          currency: "USD",
          user: User.system_user
        )

        wire.save!

        self.payout = wire
        save!

        transfer_receipts(wire.local_hcb_code)
      end
    when User::PayoutMethod::WiseTransfer
      safely do
        wise = event.wise_transfers.build(
          memo: "Payment for \"#{purpose}\"",
          amount: amount_cents,
          payment_for: "Payment for \"#{purpose}\"",
          recipient_name: payee.preferred_name,
          recipient_email: payee.email,
          address_line1: payout_method.address_line1,
          address_line2: payout_method.address_line2,
          address_city: payout_method.address_city,
          address_state: payout_method.address_state,
          address_postal_code: payout_method.address_postal_code,
          recipient_country: payout_method.recipient_country,
          bank_name: payout_method.bank_name,
          recipient_information: payout_method.recipient_information,
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
  end

  def transfer_receipts(hcb_code)
    receipts.each do |receipt|
      receipt.update!(receiptable: hcb_code)
    end
  end

end
