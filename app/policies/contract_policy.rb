# frozen_string_literal: true

class ContractPolicy < ApplicationPolicy
  def create?
    user&.admin?
  end

  def void?
    user&.admin?
  end

  def reject_and_resend?
    user&.admin?
  end

end
