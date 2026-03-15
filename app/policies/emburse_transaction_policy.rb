# frozen_string_literal: true

class EmburseTransactionPolicy < ApplicationPolicy
  def index?
    user&.auditor?
  end

  def show?
    user&.auditor? || OrganizerPosition.role_at_least?(user, record.event, :reader)
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
