# frozen_string_literal: true

class PayeePolicy < ApplicationPolicy
  def index?
    EventPolicy.new(user, record).new_payment?
  end

  def create?
    EventPolicy.new(user, record.event).new_payment?
  end

  def choose_legal_entity?
    record.legal_entity.nil? && (user.auditor? || user.email == record.email)
  end

  def set_legal_entity?
    record.legal_entity.nil? && (user.admin? || user.email == record.email)
  end

end
