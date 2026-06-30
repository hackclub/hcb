# frozen_string_literal: true

class PaymentPolicy < ApplicationPolicy
  def show?
    record.event.users.include?(user) || user&.admin?
  end

  def new?
    EventPolicy.new(user, record).new_payment?
  end

  def create?
    EventPolicy.new(user, record).create_payment?
  end

end
