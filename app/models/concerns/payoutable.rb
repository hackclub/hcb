# frozen_string_literal: true

module Payoutable
  extend ActiveSupport::Concern
  included do
    validate do
      if reimbursement_payout_holding.present? && employee_payment.present?
        errors.add(:base, "A transfer can not belong to both a reimbursement payout holding and an employee payment.")
      end
    end
  end
end
