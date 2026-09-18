# frozen_string_literal: true

# == Schema Information
#
# Table name: payroll_invoices
#
#  id                  :bigint           not null, primary key
#  aasm_state          :string           not null
#  amount_cents        :integer          not null
#  approved_at         :datetime
#  currency            :string           default("USD"), not null
#  description         :text
#  name                :text             not null
#  rejected_at         :datetime
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  payment_id          :bigint
#  payroll_position_id :bigint           not null
#  reviewed_by_id      :bigint
#
# Indexes
#
#  index_payroll_invoices_on_payment_id           (payment_id)
#  index_payroll_invoices_on_payroll_position_id  (payroll_position_id)
#  index_payroll_invoices_on_reviewed_by_id       (reviewed_by_id)
#
# Foreign Keys
#
#  fk_rails_...  (payment_id => payments.id)
#  fk_rails_...  (payroll_position_id => payroll_positions.id)
#  fk_rails_...  (reviewed_by_id => users.id)
#
module Payroll
  class Invoice < ApplicationRecord
    include AASM
    include Receiptable

    has_paper_trail

    belongs_to :payroll_position, class_name: "Payroll::Position", inverse_of: :invoices
    belongs_to :reviewed_by, class_name: "User", optional: true
    belongs_to :payment, optional: true

    has_one :event, through: :payroll_position

    monetize :amount_cents, with_model_currency: :currency

    validates :amount_cents, numericality: { greater_than: 0 }, integer_column: true
    validates :currency, inclusion: { in: Money::Currency.all.map(&:iso_code) }
    validate :currency_matches_position

    after_create_commit :notify_manager

    aasm timestamps: true do
      state :submitted, initial: true
      state :approved
      state :rejected

      event :mark_approved do
        after do |reviewed_by|
          update!(reviewed_by:)
          copy_receipts_to_payment!
        end
        transitions from: :submitted, to: :approved
      end

      event :mark_rejected do
        after do |reviewed_by|
          update!(reviewed_by:)
        end
        transitions from: :submitted, to: :rejected
      end
    end

    # Approves the invoice and creates the payment it triggers. Returns false
    # (rather than raising) if it has already been reviewed or the event can't
    # currently cover it, so callers can fall back to approving it manually
    # later. The lock keeps two concurrent approvals from paying it twice.
    def approve(reviewed_by:)
      return false if MoneyService.convert_to_usd(amount_cents, currency) > event.balance_available_v2_cents

      with_lock do
        next false unless submitted?

        update!(payment: Payment.create!(
          payee: payroll_position.payee,
          creator: reviewed_by,
          amount_cents:,
          currency:,
          purpose: name,
          classification: :general_services
        ))
        mark_approved!(reviewed_by)
      end
    end

    def receipt_required?
      true
    end

    def marked_no_or_lost_receipt_at
      nil
    end

    private

    # The document the contractor uploaded is the receipt for the payment their
    # invoice triggers, so hand it over on approval. Payment::Attempt makes the
    # same hand-off from payment to transfer, but only at the moment it creates
    # the transfer — when the payee was ready to be paid straight away that
    # already happened, so catch the transfer's HCB code up here too.
    def copy_receipts_to_payment!
      return if payment.nil?

      [payment, payment.latest_payout&.local_hcb_code].compact.each do |receiptable|
        Receipt.reupload(old_receiptable: self, new_receiptable: receiptable)
      end
    end

    # An invoice an organizer uploaded and approved in one go needs no review,
    # so there is nothing to tell the manager about.
    def notify_manager
      return if approved?

      Payroll::InvoiceMailer.with(invoice: self).submitted.deliver_later
    end

    def currency_matches_position
      return if currency == payroll_position.currency

      errors.add(:currency, "must match the position's currency")
    end

  end
end
