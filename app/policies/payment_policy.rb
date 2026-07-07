# frozen_string_literal: true

class PaymentPolicy < ApplicationPolicy
  def show?
    return true if user&.auditor?
    return true if record.legal_entity&.users&.include?(user)

    user.present? && record.event.users.exists?(id: user.id)
  end

  def new?
    EventPolicy.new(user, record).new_payment?
  end

  def create?
    EventPolicy.new(user, record).create_payment?
  end

end
