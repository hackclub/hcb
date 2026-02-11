# frozen_string_literal: true

class DocumentPolicy < ApplicationPolicy
  def common_index?
    user.auditor?
  end

  def index?
    # `record` in this context is an Event
    user.auditor? || OrganizerPosition.role_at_least?(user, record, :reader)
  end

  def new?
    user.admin?
  end

  def create?
    user.admin?
  end

  def show?
    user.auditor?
  end

  def edit?
    user.admin?
  end

  def update?
    user.admin?
  end

  def destroy?
    user.admin?
  end

  def download?
    user.auditor? || record.event.nil? || OrganizerPosition.role_at_least?(user, record.event, :reader)
  end

  def fiscal_sponsorship_letter?
    !(record&.unapproved? || record&.pending?) && !record.demo_mode? && (record.users.include?(user) || user.auditor?)
  end

  def verification_letter?
    !(record&.unapproved? || record&.pending?) && !record.demo_mode? && (record.users.include?(user) || user.auditor?) && record.account_number.present?
  end

  def toggle_archive?
    user.admin?
  end

end
