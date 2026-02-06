# frozen_string_literal: true

class LedgerPolicy < ApplicationPolicy
  def show?
    user&.auditor?
  end

end
