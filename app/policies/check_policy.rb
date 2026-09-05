# frozen_string_literal: true

class CheckPolicy < ApplicationPolicy
  def show?
    user&.auditor?
  end

end
