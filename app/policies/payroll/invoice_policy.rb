# frozen_string_literal: true

module Payroll
  class InvoicePolicy < ApplicationPolicy
    def new?
      contractor? || on_behalf?
    end

    def create?
      contractor? || on_behalf?
    end

    # Uploading on a contractor's behalf is a reviewer action, so it never
    # applies to the contractor themselves (who would otherwise self-approve).
    def on_behalf?
      return false if contractor?
      return false unless record.payroll_position.onboarded?

      reviewer?
    end

    # A contractor never reviews their own invoice, even when they are also an
    # organizer who could otherwise approve it.
    def approve?
      !contractor? && reviewer?
    end

    def reject?
      reviewer?
    end

    private

    # Only a member of the legal entity the position's payee belongs to may
    # submit invoices against it.
    def contractor?
      return false if user.blank?
      return false unless record.payroll_position.onboarded?

      legal_entity = record.payroll_position.payee.legal_entity
      legal_entity.present? && legal_entity.users.exists?(id: user.id)
    end

    # Reviewing (approving/rejecting) an invoice is gated by the same permission
    # as reviewing the underlying position.
    def reviewer?
      Payroll::PositionPolicy.new(user, record.payroll_position).review?
    end

  end
end
