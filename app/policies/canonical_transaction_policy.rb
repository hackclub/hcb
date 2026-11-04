# frozen_string_literal: true

class CanonicalTransactionPolicy < ApplicationPolicy
  def show?
    auditor_or_teammember
  end

  def set_category?
    user&.admin?
  end

  def waive_fee?
    user&.admin?
  end

  def unwaive_fee?
    user&.admin?
  end

  private

  def auditor_or_teammember
    user&.auditor? || record&.event&.users&.include?(user)
  end

end
