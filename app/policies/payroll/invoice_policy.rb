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

    # Only a member of the legal entity the position's payee belongs to may
    # submit invoices against it.
    def contractor?
      return false if user.blank?

      legal_entity = record.payroll_position.payee.legal_entity
      legal_entity.present? && legal_entity.users.exists?(id: user.id)
    end

    # Reviewing (approving/rejecting) requires organizer permission on the event.
    def reviewer?
      EventPolicy.new(user, record.event).create_contractor?
    end

  end
end
