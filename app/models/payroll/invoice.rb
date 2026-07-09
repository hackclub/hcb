# frozen_string_literal: true

# == Schema Information
#
# Table name: payroll_invoices
#
#  id                  :bigint           not null, primary key
#  aasm_state          :string           not null
#  amount_cents        :integer          default(0), not null
#  approved_at         :datetime
#  currency            :string           default("USD"), not null
#  description         :text
#  name                :text             not null
#  rejected_at         :datetime
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  payment_id          :bigint
#  payroll_contract_id :bigint           not null
#  reviewed_by_id      :bigint
#
# Indexes
#
#  index_payroll_invoices_on_payment_id           (payment_id)
#  index_payroll_invoices_on_payroll_contract_id  (payroll_contract_id)
#  index_payroll_invoices_on_reviewed_by_id       (reviewed_by_id)
#
# Foreign Keys
#
#  fk_rails_...  (payment_id => payments.id)
#  fk_rails_...  (payroll_contract_id => payroll_contracts.id)
#  fk_rails_...  (reviewed_by_id => users.id)
#
module Payroll
  class Invoice < ApplicationRecord
    include AASM

    belongs_to :payroll_contract, class_name: "Payroll::Contract", inverse_of: :invoices
    belongs_to :reviewed_by, class_name: "User", optional: true
    belongs_to :payment, optional: true

    has_one :receipt, as: :receiptable

    monetize :amount_cents, with_model_currency: :currency

    validate :currency_matches_contract

    aasm timestamps: true do
      state :submitted, initial: true
      state :approved
      state :rejected

      event :mark_approved do
        transitions from: :submitted, to: :approved
      end

      event :mark_rejected do
        transitions from: :submitted, to: :rejected
      end
    end

    private

    def currency_matches_contract
      return if payroll_contract.blank? || currency == payroll_contract.currency

      errors.add(:currency, "must match the contract's currency")
    end

  end
end
