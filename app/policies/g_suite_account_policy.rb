# frozen_string_literal: true

class GSuiteAccountPolicy < ApplicationPolicy
  def index?
    user.auditor?
  end

  def create?
    admin_or_manager?
  end

  def show?
    user.auditor? || (record.event.users.include?(user) && !record.g_suite.revocation.present?)
  end

  def reset_password?
    admin_or_manager?
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

  def reject?
    user.admin?
  end

  def toggle_suspension?
    admin_or_manager?
  end

  private

  def admin_or_manager?
    user&.admin? || (OrganizerPosition.find_by(user:, event: record.event)&.manager? && !record.g_suite.revocation.present?)
  end

end
