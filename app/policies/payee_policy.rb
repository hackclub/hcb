# frozen_string_literal: true

class PayeePolicy < ApplicationPolicy
  def index?
    EventPolicy.new(user, record).new_payment?
  end

  def create?
    EventPolicy.new(user, record.event).new_payment?
  end

  def update?
    member?
  end

  def destroy?
    member? && record.archivable?
  end

  private

  def member?
    user&.admin? || OrganizerPosition.role_at_least?(user, record.event, :member)
  end

end
