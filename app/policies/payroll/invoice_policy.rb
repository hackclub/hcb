# frozen_string_literal: true

module Payroll
  class InvoicePolicy < ApplicationPolicy
    def new?
      contractor?
    end

    def create?
      contractor?
    end

    private

    # Only the contractor the position belongs to may submit invoices against it.
    def contractor?
      user.present? && record.payroll_position.payee.email == user.email
    end

  end
end
