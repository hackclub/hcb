# frozen_string_literal: true

class PayeePolicy < ApplicationPolicy
  def index?
    EventPolicy.new(user, record).create_payment?
  end

  def create?
    EventPolicy.new(user, record.event).create_payment?
  end

  def update?
    manager?
  end

  def archive?
    manager?
  end

  def choose_legal_entity?
    user.auditor? || user.email == record.email
  end

  def set_legal_entity?
    record.legal_entity.nil? && (user.admin? || user.email == record.email)
  end

  private

  def manager?
    user&.admin? || OrganizerPosition.role_at_least?(user, record.event, :manager)
  end

end
