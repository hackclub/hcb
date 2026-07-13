# frozen_string_literal: true

class LegalEntityPolicy < ApplicationPolicy
  def show?
    user.auditor? || record.users.include?(user)
  end

  def replace?
    user.admin? || record.users.include?(user)
  end

end
