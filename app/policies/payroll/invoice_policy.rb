# frozen_string_literal: true

module Payroll
  class InvoicePolicy < ApplicationPolicy
    def new?
      contractor? || on_behalf?
    end

    def create?
      contractor? || on_behalf?
    end

    def on_behalf?
      record.payroll_position.onboarded? && reviewer?
    end

    def approve?
      reviewer?
    end

    def reject?
      reviewer?
    end

    private

    # Only a member of the legal entity the position's payee belongs to may
    # submit invoices against it.
    def contractor?
      record.payroll_position.onboarded? && payee_member?
    end

    def payee_member?
      return false if user.blank?

      legal_entity = record.payroll_position.payee.legal_entity
      legal_entity.present? && legal_entity.users.exists?(id: user.id)
    end

    # Reviewing (approving/rejecting) an invoice is gated by the same permission
    # as reviewing the underlying position, and never by the contractor themselves.
    def reviewer?
      !payee_member? && Payroll::PositionPolicy.new(user, record.payroll_position).review?
    end

  end
end
