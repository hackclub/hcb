# frozen_string_literal: true

class CheckDepositPolicy < ApplicationPolicy
  def index?
    auditor_or_user? && check_deposits_enabled?
  end

  def create?
    admin_or_member_user? && !record.event.demo_mode?
  end

  def view_image?
    auditor_or_manager?
  end

  def toggle_fronted?
    admin?
  end

  private

  def admin?
    user&.admin?
  end

  def auditor?
    user&.auditor?
  end

  def user?
    record.event.users.include?(user)
  end

  def check_deposits_enabled?
    record.event.plan.check_deposits_enabled?
  end

  def admin_or_member_user?
    OrganizerPosition.role_at_least?(user, record.event, :member)
  end

  def auditor_or_user?
    auditor? || user?
  end

  def auditor_or_manager?
    user&.admin? || OrganizerPosition.find_by(user:, event: record.event)&.manager?
  end

  def user_who_can_transfer?
    EventPolicy.new(user, record.event).create_transfer?
  end

end
