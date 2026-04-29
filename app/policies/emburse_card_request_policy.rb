# frozen_string_literal: true

class EmburseCardRequestPolicy < ApplicationPolicy
  def index?
    auditor?
  end

  def show?
    auditor?
  end

  def export?
    auditor?
  end

end
