# frozen_string_literal: true

class WiseTransferPolicy < ApplicationPolicy
  def new?
    auditor_or_user?
  end

  def create?
    user_who_can_transfer?
  end

  def approve?
    admin?
  end

  def reject?
    user_who_can_transfer?
  end

  def update?
    admin?
  end

  def mark_sent?
    admin?
  end

  def mark_failed?
    user_who_can_transfer?
  end

  def generate_quote?
    auditor? || user.events.any?
  end

  private

  def auditor_or_user?
    auditor? || OrganizerPosition.role_at_least?(user, record.event, :reader)
  end

  def admin_or_user?
    admin? || OrganizerPosition.role_at_least?(user, record.event, :reader)
  end

  def user_who_can_transfer?
    EventPolicy.new(user, record.event).create_transfer?
  end

end
