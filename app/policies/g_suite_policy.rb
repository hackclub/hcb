# frozen_string_literal: true

class GSuitePolicy < ApplicationPolicy
  def index?
    user.auditor?
  end

  def create?
    user.admin?
  end

  def show?
    user.auditor? || (OrganizerPosition.role_at_least?(user, record.event, :reader) && !record.revocation.present?)
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

  def status?
    user.auditor? || (OrganizerPosition.role_at_least?(user, record.event, :reader) && !record.revocation.present?)
  end

end
