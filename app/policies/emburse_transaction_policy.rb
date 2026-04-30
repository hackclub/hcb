# frozen_string_literal: true

class EmburseTransactionPolicy < ApplicationPolicy
  def index?
    auditor?
  end

  def show?
    auditor? || OrganizerPosition.role_at_least?(user, record.event, :reader)
  end

  def edit?
    admin?
  end

  def update?
    admin?
  end

  private

  def is_public
    record.event.is_public?
  end

end
