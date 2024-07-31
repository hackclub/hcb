# frozen_string_literal: true

class CheckDepositPolicy < ApplicationPolicy
  def index?
    admin_or_user?
  end

  def create?
    admin_or_user? && !record.event.demo_mode? && !record.event.outernet_guild?
  end

  def view_image?
    admin_or_manager?
  end

  private

  def admin_or_user?
    user&.admin? || record.event.users.include?(user)
  end

  def admin_or_manager?
    user&.admin? || OrganizerPosition.find_by(user:, event: record.event)&.manager?
  end

  def user_who_can_transfer?
    EventPolicy.new(user, record.event).create_transfer?
  end

end
