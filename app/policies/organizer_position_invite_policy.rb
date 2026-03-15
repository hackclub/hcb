# frozen_string_literal: true

class OrganizerPositionInvitePolicy < ApplicationPolicy
  def index?
    user&.auditor? || record.event&.users&.include?(user)
  end

  def new?
    admin_or_manager?
  end

  def create?
    admin_or_manager?
  end

  def show?
    user&.auditor? || record.user == user
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

  def destroy?
    cancel?
  end

  def resend?
    admin_or_manager? || (record.sender == user && record.event&.users&.include?(user))
  end

  def change_position_role?
    admin_or_manager? && !record.signee?
  end

  def send_contract?
    user&.admin?
  end

  private

  def admin_or_manager?
    user&.admin? || OrganizerPosition.role_at_least?(user, record.event, :manager)
  end

end
