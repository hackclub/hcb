# frozen_string_literal: true

class GSuiteAccountPolicy < ApplicationPolicy
  def index?
    auditor?
  end

  def create?
    admin_or_manager?
  end

  def show?
    auditor? || (OrganizerPosition.role_at_least?(user, record.event, :reader) && !record.g_suite.revocation.present?)
  end

  def reset_password?
    admin_or_manager?
  end

  def edit?
    admin?
  end

  def update?
    admin?
  end

  def destroy?
    admin_or_manager?
  end

  def reject?
    admin?
  end

  def toggle_suspension?
    admin_or_manager?
  end

  private

  def admin_or_manager?
    return true if admin?

    revocation = record.is_a?(GSuite) ? record.revocation : record&.g_suite&.revocation
    OrganizerPosition.role_at_least?(user, record.event, :manager) && !revocation&.revoked?
  end

end
