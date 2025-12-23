# frozen_string_literal: true

class ContractPolicy < ApplicationPolicy
  def create?
    user&.admin?
  end

  def void?
    user&.admin?
  end

end
