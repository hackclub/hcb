# frozen_string_literal: true

class BankAccountPolicy < ApplicationPolicy
  def index?
    auditor?
  end

  def new?
    admin?
  end

  def update?
    admin?
  end

  def create?
    admin?
  end

  def show?
    auditor?
  end

  def reauthenticate?
    admin?
  end

end
