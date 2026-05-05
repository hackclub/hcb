# frozen_string_literal: true

class LedgerPolicy < ApplicationPolicy
  def show?
    auditor?
  end

end
