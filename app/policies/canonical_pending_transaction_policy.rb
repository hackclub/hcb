# frozen_string_literal: true

class CanonicalPendingTransactionPolicy < ApplicationPolicy
  def show?
    auditor_or_teammember
  end

  def update?
    admin_or_teammember
  end

  def set_category?
    user&.admin?
  end

  private

  def admin_or_teammember
    user&.admin? || OrganizerPosition.role_at_least?(user, record&.event, :reader)
  end

  def auditor_or_teammember
    user&.auditor? || OrganizerPosition.role_at_least?(user, record&.event, :reader)
  end

end
