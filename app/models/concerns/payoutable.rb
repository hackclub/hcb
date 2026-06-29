# frozen_string_literal: true

module Payoutable
  extend ActiveSupport::Concern
  included do
    validate do
      associations = [reimbursement_payout_holding, employee_payment, payment_attempt].count(&:present?)
      if associations > 1
        errors.add(:base, "A transfer can not belong to more than one of: reimbursement payout holding, employee payment, or payment attempt.")
      end
    end
  end
end
