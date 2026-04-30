# frozen_string_literal: true

class ApiTokenPolicy < ApplicationPolicy
  def make_eternal?
    admin?
  end

end
