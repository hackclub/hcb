# frozen_string_literal: true

class WirePolicy < ApplicationPolicy
  def new?
    admin_or_user?
  end

  def create?
    user_who_can_transfer?
  end

  def approve?
    user&.admin?
  end

  def reject?
    user_who_can_transfer?
  end

  private

  def admin_or_user?
    user&.admin? || record.event.users.include?(user)
  end

  def user_who_can_transfer?
    EventPolicy.new(user, record.event).create_transfer?
  end

end
