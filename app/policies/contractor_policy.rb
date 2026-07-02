# frozen_string_literal: true

class ContractorPolicy < ApplicationPolicy
  def show?
    EventPolicy.new(user, record).contractors?
  end

  def new?
    EventPolicy.new(user, record).new_contractor?
  end

  def create?
    EventPolicy.new(user, record).create_contractor?
  end

end
