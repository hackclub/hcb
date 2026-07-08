# frozen_string_literal: true

class PayeePolicy < ApplicationPolicy
  def index?
    EventPolicy.new(user, record).new_payment?
  end

  def create?
    EventPolicy.new(user, record.event).new_payment?
  end

  def update?
    manager? || (member? && !payment_sent?)
  end

  def edit_details?
    manager?
  end

  def destroy?
    manager? && record.archivable?
  end

  private

  def manager?
    user&.admin? || OrganizerPosition.role_at_least?(user, record.event, :manager)
  end

  def member?
    OrganizerPosition.role_at_least?(user, record.event, :member)
  end

  def payment_sent?
    record.payments.exists?
  end

end
