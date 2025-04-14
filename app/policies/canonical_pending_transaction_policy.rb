# frozen_string_literal: true

class CanonicalPendingTransactionPolicy < ApplicationPolicy
  def show?
    auditor_or_teammember
  end

  def edit?
    admin_or_teammember
  end

  def update?
    admin_or_teammember
  end

  private

  def admin_or_teammember
    user&.admin? || record&.event&.users&.include?(user)
  end

  def auditor_or_teammember
    user&.auditor? || record&.event&.users&.include?(user)
  end

end
