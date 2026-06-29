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

    # This method should be overwritten in specific classes
    def can_cancel?
      raise NotImplementedError, "The #{self.class.name} model includes Payoutable, but hasn't implemented it's own version of can_cancel?"
    end

    # Cancels the transfer if possible, whether it's under review or already in transit
    # This method should be overwritten in specific classes
    def cancel!
      raise NotImplementedError, "The #{self.class.name} model includes Payoutable, but hasn't implemented it's own version of cancel!"
    end
  end
end
