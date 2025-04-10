# frozen_string_literal: true

class IncreaseCheckPolicy < ApplicationPolicy
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
    OrganizerPosition.role_at_least?(user, record.event, :member)
  end

  def user_who_can_transfer?
    EventPolicy.new(user, record.event).create_transfer?
  end

end
