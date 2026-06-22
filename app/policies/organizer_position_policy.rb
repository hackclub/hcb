# frozen_string_literal: true

class OrganizerPositionPolicy < ApplicationPolicy
  def destroy?
    admin_or_owner?
  end

  def set_index?
    record.user == user
  end

  def mark_visited?
    record.user == user
  end

  def change_position_role?
    return false unless user
    return true if admin?
    return false if record.user == user
    return false if record.owner?

    manager?
  end

  def can_request_removal?
    admin_or_manager? || record.user == user
  end

  def view_allowances?
    admin_or_manager? || record.user == user || user&.auditor?
  end

  private

  def admin_or_manager?
    admin? || manager?
  end

  def admin_or_owner?
    admin? || OrganizerPosition.find_by(user:, event: record.event)&.owner?
  end

  def admin?
    user&.admin?
  end

  def manager?
    OrganizerPosition.role_at_least?(user, record.event, :manager) # This is not just `record`!
  end

end
