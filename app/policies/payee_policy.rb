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

  def choose_legal_entity?
    user.auditor? || user.email == record.email
  end

  def set_legal_entity?
    record.legal_entity.nil? && (user.admin? || user.email == record.email)
  end

end
