# frozen_string_literal: true

class ContractPolicy < ApplicationPolicy
  def create?
    user&.admin?
  end

  def void?
    user&.admin?
  end

  def resend_to_user?
    user&.admin?
  end

  def resend_to_cosigner?
    user&.admin?
  end

  def show?
    record.user == user || user&.admin?
  end

end
