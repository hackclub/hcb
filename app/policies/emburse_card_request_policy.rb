# frozen_string_literal: true

class EmburseCardRequestPolicy < ApplicationPolicy
  def index?
    user&.auditor?
  end

  def show?
    user&.auditor?
  end

  def export?
    user&.auditor?
  end

end
