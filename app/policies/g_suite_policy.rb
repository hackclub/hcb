# frozen_string_literal: true

class GSuitePolicy < ApplicationPolicy
  def index?
    user.auditor?
  end

  def create?
    user.admin?
  end

  def show?
    user.auditor? || record.event.users.include?(user)
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
    user.auditor? || record.event.users.include?(user)
  end

end
