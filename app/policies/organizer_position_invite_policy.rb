# frozen_string_literal: true

class OrganizerPositionInvitePolicy < ApplicationPolicy
  def index?
    user&.admin? || record.event&.users&.include?(user)
  end

  def new?
    admin_or_manager?
  end

  def create?
    admin_or_manager?
  end

  def show?
    user&.admin? || record.user == user
  end

  def accept?
    record.user == user
  end

  def reject?
    record.user == user
  end

  def cancel?
    admin_or_manager? || (record.sender == user && record.event&.users&.include?(user))
  end

  def resend?
    admin_or_manager? || (record.sender == user && record.event&.users&.include?(user))
  end

  def toggle_signee_status?
    user&.admin?
  end

  def change_position_role?
    admin_or_manager?
  end

  private

  def admin_or_manager?
    user&.admin? || OrganizerPosition.find_by(user:, event: record.event)&.manager?
  end

end
