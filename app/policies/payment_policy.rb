# frozen_string_literal: true

class PaymentPolicy < ApplicationPolicy
  def new?
    EventPolicy.new(user, record.event).new_payment?
  end

  def create?
    EventPolicy.new(user, record.event).create_payment?
  end

end
