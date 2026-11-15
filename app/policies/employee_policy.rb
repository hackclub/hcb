# frozen_string_literal: true

class EmployeePolicy < ApplicationPolicy
  def new?
    admin || team_member
  end

  def create?
    !record.event.demo_mode && (admin || manager)
  end

  def show?
    team_member || admin || employee || auditor
  end

  def onboard?
    admin
  end

  def terminate?
    admin || manager
  end

  def destroy?
    (manager || admin) && record.onboarding?
  end

  private

  def admin
    user&.admin?
  end

  def auditor
    user&.auditor?
  end

  def manager
    OrganizerPosition.role_at_least?(user, record.event, :manager)
  end

  def team_member
    OrganizerPosition.role_at_least?(user, record.event, :reader)
  end

  def employee
    record.user == user
  end

end
