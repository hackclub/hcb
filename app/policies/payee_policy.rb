# frozen_string_literal: true

class PayeePolicy < ApplicationPolicy
  def index?
    EventPolicy.new(user, record).new_payment?
  end

  def create?
    EventPolicy.new(user, record).new_payment?
  end

end
