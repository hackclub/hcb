# frozen_string_literal: true

class TransactionPolicy < ApplicationPolicy
  def index?
    user&.auditor?
  end

  def export?
    user&.auditor? ||
      record.all? { |r| r.event.users.include? user }
  end

  def show?
    # removing is_public check due to https://github.com/hackclub/hcb/issues/675
    # is_public || admin_or_teammember
    auditor_or_teammember
  end

  def edit?
    admin_or_teammember
  end

  def update?
    admin_or_teammember
  end

  private

  def auditor_or_teammember
    user&.auditor? || OrganizerPosition.role_at_least?(user, :reader)
  end

  def admin_or_teammember
    OrganizerPosition.role_at_least?(user, :member)
  end

  def is_public
    record&.event&.is_public?
  end

end
