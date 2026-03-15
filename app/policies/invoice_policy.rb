# frozen_string_literal: true

class InvoicePolicy < ApplicationPolicy
  def index?
    return true if user&.auditor?

    event_ids = record.map(&:sponsor).map(&:event).pluck(:id)
    same_event = event_ids.uniq.size == 1 # same_event is a sanity check that all the records are from the same event
    return false unless Event.find(event_ids.first).plan.invoices_enabled?
    return false if same_event && Event.find(event_ids.first).unapproved?
    return true if Event.find(event_ids.first).is_public?
    return true if same_event && user&.events&.pluck(:id)&.include?(event_ids.first)
  end

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

  def pdf?
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
