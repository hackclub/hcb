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

    validates :currency, inclusion: { in: Money::Currency.all.map(&:iso_code) }
    validate :currency_matches_position

    aasm timestamps: true do
      state :submitted, initial: true
      state :approved
      state :rejected

      event :mark_approved do
        after do |reviewed_by|
          update!(reviewed_by:)
        end
        transitions from: :submitted, to: :approved
      end

      event :mark_rejected do
        transitions from: :submitted, to: :rejected
      end
    end

    def receipt_required?
      true
    end

    def marked_no_or_lost_receipt_at
      nil
    end

    private

    def currency_matches_position
      return if currency == payroll_position.currency

      errors.add(:currency, "must match the position's currency")
    end

  end
end
