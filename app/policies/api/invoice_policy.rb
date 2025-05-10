# frozen_string_literal: true

module Api
  class InvoicePolicy < ApplicationPolicy
    def show?
      record.event.is_public? || OrganizerPosition.role_at_least?(user, record, :reader)
    end

    def create?
      !record.unapproved? && record.plan.invoices_enabled? && OrganizerPosition.role_at_least?(user, record, :member)
    end

    def unapproved?
      record&.sponsor&.event&.unapproved?
    end

  end

end
