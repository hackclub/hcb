# frozen_string_literal: true

class ContractPolicy < ApplicationPolicy
  def create?
    admin?
  end

  def void?
    admin?
  end

  def reissue?
    admin?
  end

end
