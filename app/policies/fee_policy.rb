# frozen_string_literal: true

class FeePolicy < ApplicationPolicy
  def create?
    user&.admin?
  end

end
