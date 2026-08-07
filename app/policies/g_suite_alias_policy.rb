# frozen_string_literal: true

class GSuiteAliasPolicy < ApplicationPolicy
  def create?
    admin_or_manager?
  end

  def destroy?
    admin_or_manager?
  end

  private

  def admin_or_manager?
    user&.admin? || OrganizerPosition.role_at_least?(user, record.g_suite.event, :manager)
  end

end
