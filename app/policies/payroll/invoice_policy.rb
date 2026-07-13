# frozen_string_literal: true

module Payroll
  class InvoicePolicy < ApplicationPolicy
    def new?
      contractor?
    end

    def create?
      contractor?
    end

    def approve?
      reviewer?
    end

    def reject?
      reviewer?
    end

    private

    # Only the contractor the position belongs to may submit invoices against it.
    def contractor?
      user.present? && record.payroll_position.payee.email == user.email
    end

    # Reviewing (approving/rejecting) requires organizer permission on the event.
    def reviewer?
      EventPolicy.new(user, record.event).create_contractor?
    end

  end
end
