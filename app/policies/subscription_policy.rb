# frozen_string_literal: true

class SubscriptionPolicy < ApplicationPolicy
  def show?
    enabled? && (auditor? || reader?)
  end

  def create?
    enabled? && member?
  end

  def update?
    enabled? && member?
  end

  def cancel?
    update?
  end

  def destroy?
    update?
  end

  private

  def enabled?
    Subscription.enabled_for?(record.event)
  end

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
