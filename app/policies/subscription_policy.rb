# frozen_string_literal: true

class SubscriptionPolicy < ApplicationPolicy
  def show?
    auditor? || reader?
  end

  def create?
    member?
  end

  def update?
    member?
  end

  def cancel?
    update?
  end

  def destroy?
    update?
  end

  private

  def auditor?
    user&.auditor?
  end

  def reader?
    OrganizerPosition.role_at_least?(user, record.event, :reader)
  end

  def member?
    OrganizerPosition.role_at_least?(user, record.event, :member)
  end

end
