# frozen_string_literal: true

class PaymentPolicy < ApplicationPolicy
  def new?
    EventPolicy.new(user, record).new_payment?
  end

  def create?
    EventPolicy.new(user, record).create_payment?
  end

end
