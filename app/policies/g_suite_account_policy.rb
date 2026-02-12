# frozen_string_literal: true

class GSuiteAccountPolicy < ApplicationPolicy
  def index?
    user.auditor?
  end

  def create?
    admin_or_manager?
  end

  def show?
    user.auditor? || (OrganizerPosition.role_at_least?(user, record.event, :reader) && !record.g_suite.revocation.present?)
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
    return true if user&.admin?

    revocation = record.is_a?(GSuite) ? record.revocation : record&.g_suite&.revocation
    OrganizerPosition.role_at_least?(user, record.event, :manager) && !revocation&.revoked?
  end

end
