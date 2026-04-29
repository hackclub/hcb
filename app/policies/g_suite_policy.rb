# frozen_string_literal: true

class GSuitePolicy < ApplicationPolicy
  def index?
    auditor?
  end

  def create?
    admin?
  end

  def show?
    auditor? || (OrganizerPosition.role_at_least?(user, record.event, :reader) && !record.revocation.present?)
  end

  def edit?
    admin?
  end

  def update?
    admin?
  end

  def destroy?
    admin?
  end

  def status?
    auditor? || (OrganizerPosition.role_at_least?(user, record.event, :reader) && !record.revocation.present?)
  end

end
