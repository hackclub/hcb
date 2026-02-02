# frozen_string_literal: true

class LedgerPolicy < ApplicationPolicy
  def show?
    user&.admin?
  end

end
