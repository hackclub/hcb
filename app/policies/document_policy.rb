# frozen_string_literal: true

class DocumentPolicy < ApplicationPolicy
  def common_index?
    auditor?
  end

  def index?
    # `record` in this context is an Event
    auditor? || OrganizerPosition.role_at_least?(user, record, :reader)
  end

  def new?
    admin?
  end

  def create?
    admin?
  end

  def show?
    auditor?
  end

  def edit?
    admin?
  end

  def update?
    admin?
  end

  def destroy?
    admin?
  end

  def download?
    auditor? || record.event.nil? || OrganizerPosition.role_at_least?(user, record.event, :reader)
  end

  def fiscal_sponsorship_letter?
    !(record&.unapproved? || record&.pending?) && !record.demo_mode? && (OrganizerPosition.role_at_least?(user, record, :reader) || auditor?)
  end

  def verification_letter?
    !(record&.unapproved? || record&.pending?) && !record.demo_mode? && (OrganizerPosition.role_at_least?(user, record, :reader) || auditor?) && record.account_number.present?
  end

  def toggle_archive?
    admin?
  end

end
