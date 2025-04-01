# frozen_string_literal: true

class InvoicePolicy < ApplicationPolicy
  def index?
    return true if user&.auditor?
    return true if record.blank?

    event_ids = record.map(&:sponsor).map(&:event).pluck(:id)
    same_event = event_ids.uniq.size == 1 # same_event is a sanity check that all the records are from the same event
    return false unless Event.find(event_ids.first).plan.invoices_enabled?
    return false if same_event && Event.find(event_ids.first).unapproved?
    return true if Event.find(event_ids.first).is_public?
    return true if same_event && user&.events&.pluck(:id)&.include?(event_ids.first)
  end

  def new?
    !unapproved? && (is_public || admin_or_user)
  end

  def create?
    !record.unapproved? && record.plan.invoices_enabled? && admin_or_user
  end

  def show?
    is_public || user&.auditor || OrganizerPosition.role_at_least?(user, record&.sponsor&.event, :reader)
  end

  def archive?
    admin_or_user
  end

  def void?
    admin_or_user
  end

  def unarchive?
    admin_or_user
  end

  def manually_mark_as_paid?
    admin_or_user
  end

  def hosted?
    admin_or_user
  end

  def pdf?
    user&.auditor? || OrganizerPosition.role_at_least?(user, record&.sponsor&.event, :reader)
  end

  def refund?
    user&.admin?
  end

  private

  def admin_or_user
    OrganizerPosition.role_at_least?(user, record&.sponsor&.event, :member)
  end

  def is_public
    record&.sponsor&.event&.is_public?
  end

  def unapproved?
    record&.sponsor&.event&.unapproved?
  end

end
