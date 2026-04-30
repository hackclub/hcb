# frozen_string_literal: true

class StripeCardholderPolicy < ApplicationPolicy
  def new?
    admin? || record&.user = user
  end

  def create?
    admin? || record&.user = user
  end

  def update?
    admin? || record&.event&.users&.include?(user)
  end

  def update_profile?
    admin? || record&.user == user
  end

end
