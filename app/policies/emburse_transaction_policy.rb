# frozen_string_literal: true

class EmburseTransactionPolicy < ApplicationPolicy
  def index?
    user&.admin?
  end

  def show?
    user&.admin? || record.event.users.include?(user)
  end

  def edit?
    user&.admin?
  end

  def update?
    user&.admin?
  end

  private

  def is_public
    record.event.is_public?
  end

end
