# frozen_string_literal: true

class PayeePolicy < ApplicationPolicy
  def index?
    EventPolicy.new(user, record).new_payment?
  end

  def create?
    # Creating a payee moves money, so it's limited to managers/admins even
    # though the payments page itself is viewable by readers.
    EventPolicy.new(user, record.event).create_payment?
  end

  def update?
    member?
  end

  def archive?
    member?
  end

  def choose_legal_entity?
    user.auditor? || user.email == record.email
  end

  def set_legal_entity?
    record.legal_entity.nil? && (user.admin? || user.email == record.email)
  end

  private

  def member?
    user&.admin? || OrganizerPosition.role_at_least?(user, record.event, :member)
  end

end
