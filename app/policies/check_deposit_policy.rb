# frozen_string_literal: true

class CheckDepositPolicy < ApplicationPolicy
  def index?
    auditor_or_user? && check_deposits_enabled?
  end

  def create?
    OrganizerPosition.role_at_least?(user, record.event, :member) && !record.event.demo_mode?
  end

  def view_image?
    # You can view the check deposit images (front & back) as long as you meet
    # at least one of the following conditions:
    # - You're an auditor (admin)
    # - You're a manager of the event
    # - You're an organizer of the event (e.g. reader, member, etc.), but ALSO
    #   was the person who uploaded the check deposit.
    auditor_or_manager? || (user? && record.created_by == user)
  end

  def toggle_fronted?
    admin?
  end

  private

  def admin?
    user&.admin?
  end

  def auditor?
    user&.auditor?
  end

  def user?
    record.event.users.include?(user)
  end

  def check_deposits_enabled?
    record.event.plan.check_deposits_enabled?
  end

  def auditor_or_user?
    auditor? || user?
  end

  def auditor_or_manager?
    auditor? || OrganizerPosition.role_at_least?(user, record.event, :manager)
  end

  def user_who_can_transfer?
    EventPolicy.new(user, record.event).create_transfer?
  end

end
