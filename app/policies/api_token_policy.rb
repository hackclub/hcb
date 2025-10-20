# frozen_string_literal: true

class ApiTokenPolicy < ApplicationPolicy
  def make_eternal?
    user&.admin?
  end

end
