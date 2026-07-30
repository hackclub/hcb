# frozen_string_literal: true

class PaymentPolicy < ApplicationPolicy
  def show?
    return true if user&.auditor?
    return true if user.present? && record.legal_entity&.users&.exists?(id: user.id)

    user.present? && record.event.users.exists?(id: user.id)
  end

  def new?
    EventPolicy.new(user, record).new_payment?
  end

  def create?
    EventPolicy.new(user, record).create_payment?
  end

  def cancel?
    EventPolicy.new(user, record.event).create_payment?
  end

end
