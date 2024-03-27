# frozen_string_literal: true

class InvoicePolicy < ApplicationPolicy
  def index?
    return true if user&.admin?
    return true if record.blank?

    event_ids = record.map(&:sponsor).map(&:event).pluck(:id)
    same_event = event_ids.uniq.size == 1 # same_event is a sanity check that all the records are from the same event
    return false if same_event && Event.find(event_ids.first).unapproved?
    return true if Event.find(event_ids.first).is_public?
    return true if same_event && user&.events&.pluck(:id)&.include?(event_ids.first)
  end

  def new?
    (is_public? || admin_or_user?) && !unapproved?
  end

  def create?
    admin_or_user? && !record.unapproved?
  end

  def show?
    is_public? || admin_or_user?
  end

  def archive?
    admin_or_user?
  end

  def void?
    admin_or_user?
  end

  def unarchive?
    admin_or_user?
  end

  def manual_payment?
    user&.admin?
  end

  def manually_mark_as_paid?
    user&.admin?
  end

  def hosted?
    admin_or_user?
  end

  def pdf?
    admin_or_user?
  end

  private

  def admin_or_user?
    user&.admin? || record.sponsor.event.users.include?(user)
  end

  def admin_or_manager?
    user&.admin? || OrganizerPosition.find_by(user: event: record&.sponsor&.event)&.manager?
  end

  def is_public
    record&.sponsor&.event&.is_public?
  end

  def unapproved?
    record&.sponsor&.event&.unapproved?
  end

end
