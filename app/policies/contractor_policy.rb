# frozen_string_literal: true

class ContractorPolicy < ApplicationPolicy
  def new?
    EventPolicy.new(user, record).new_contractor?
  end

  def create?
    EventPolicy.new(user, record).create_contractor?
  end

end
