# frozen_string_literal: true

class InvoicePolicy < ApplicationPolicy
  def new?
    !unapproved? && (is_public || OrganizerPosition.role_at_least?(user, record&.sponsor&.event, :reader))
  end

  def create?
    !record.unapproved? && record.plan.invoices_enabled? && OrganizerPosition.role_at_least?(user, record, :member)
  end

  def show?
    is_public || auditor_or_reader?
  end

  def archive?
    admin_or_manager?
  end

  def void?
    admin_or_manager?
  end

  def unarchive?
    admin_or_manager?
  end

  def manually_mark_as_paid?
    admin_or_manager?
  end

  def hosted?
    auditor_or_reader?
  end

  def refund?
    user&.admin?
  end

  def show_in_v4?
    auditor_or_reader?
  end

  def auditor_or_reader?
    user&.auditor? || OrganizerPosition.role_at_least?(user, event, :reader)
  end

  def admin_or_manager?
    user&.admin? || OrganizerPosition.role_at_least?(user, event, :manager)
  end

  private

  def event
    return record.event if record.respond_to?(:event)

    record&.sponsor&.event
  end

  def is_public
    event&.is_public?
  end

  def unapproved?
    event&.unapproved?
  end

end
