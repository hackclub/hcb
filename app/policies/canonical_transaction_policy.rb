# frozen_string_literal: true

class CanonicalTransactionPolicy < ApplicationPolicy
  def show?
    admin_or_teammember || record.stripe_cardholder.user_id == user.id
  end

  def edit?
    admin_or_teammember
  end

  def set_custom_memo?
    admin_or_teammember
  end

  def export?
    admin_or_teammember
  end

  def waive_fee?
    user&.admin?
  end

  def unwaive_fee?
    user&.admin?
  end

  def mark_bank_fee?
    user&.admin?
  end

  private

  def admin_or_teammember
    user&.admin? || record&.event&.users&.include?(user)
  end

end
