# frozen_string_literal: true

# == Schema Information
#
# Table name: payroll_contracts
#
#  id            :bigint           not null, primary key
#  aasm_state    :string           not null
#  end_date      :date             not null
#  expired_at    :datetime
#  onboarded_at  :datetime
#  onboarding_at :datetime
#  purpose       :text             not null
#  rate_cents    :integer          default(0), not null
#  start_date    :date             not null
#  terminated_at :datetime
#  title         :text             not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  contract_id   :bigint
#  payee_id      :bigint           not null
#
# Indexes
#
#  index_payroll_contracts_on_contract_id  (contract_id)
#  index_payroll_contracts_on_payee_id     (payee_id)
#
# Foreign Keys
#
#  fk_rails_...  (contract_id => contracts.id)
#  fk_rails_...  (payee_id => payees.id)
#
module Payroll
  class Contract < ApplicationRecord
    include AASM

    belongs_to :payee
    belongs_to :contract, class_name: "Contract", optional: true

    has_many :invoices, class_name: "Payroll::Invoice", foreign_key: "payroll_contract_id", inverse_of: :payroll_contract, dependent: :destroy

    monetize :rate_cents

    validate :end_date_after_start_date

    aasm timestamps: true do
      state :under_review, initial: true
      state :onboarding
      state :onboarded
      state :expired
      state :terminated

      event :mark_onboarding do
        transitions from: :under_review, to: :onboarding
      end

      event :mark_onboarded do
        transitions from: :onboarding, to: :onboarded
      end

      event :mark_expired do
        transitions from: :onboarded, to: :expired
      end

      event :mark_terminated do
        transitions from: [:under_review, :onboarding, :onboarded], to: :terminated
      end
    end

    private

    def end_date_after_start_date
      return if start_date.blank? || end_date.blank?

      errors.add(:end_date, "must be after the start date") if end_date <= start_date
    end

  end
end
