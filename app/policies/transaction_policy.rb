# frozen_string_literal: true

class TransactionPolicy < ApplicationPolicy
  def index?
    user&.admin?
  end

  def export?
    user&.admin? ||
      record.all? { |r| r.event.users.include? user }
  end

  def show?
    # removing is_public check due to https://github.com/hackclub/hcb/issues/675
    # is_public || admin_or_teammember
    admin_or_teammember
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

  def is_public
    record&.event&.is_public?
  end

end
