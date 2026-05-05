# frozen_string_literal: true

class WirePolicy < ApplicationPolicy
  def new?
    auditor_or_user?
  end

  def create?
    user_who_can_transfer?
  end

  def approve?
    admin?
  end

  def send_wire?
    admin?
  end

  def reject?
    user_who_can_transfer?
  end

  def edit?
    admin?
  end

  def update?
    admin?
  end

  private


  def auditor_or_user?
    auditor? || OrganizerPosition.role_at_least?(user, record.event, :reader)
  end

  def admin_or_user?
    admin? || OrganizerPosition.role_at_least?(user, record.event, :reader)
  end

  def user_who_can_transfer?
    EventPolicy.new(user, record.event).create_transfer?
  end

end
