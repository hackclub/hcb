# frozen_string_literal: true

class OrganizerPositionPolicy < ApplicationPolicy
  def destroy?
    admin_or_contract_signee?
  end

  def set_index?
    record.user == user
  end

  def mark_visited?
    record.user == user
  end

  def toggle_signee_status?
    user.admin?
  end

  def change_position_role?
    return false unless user
    return false if record.user == user

    admin_or_manager?
  end

  def can_request_removal?
    admin_or_manager? || record.user == user
  end

  def view_allowances?
    admin_or_manager? || record.user == user || user&.auditor?
  end

  private

  def admin_or_manager?
    user&.admin? ||
      OrganizerPosition.find_by(user:, event: record.event)&.manager? # This is not just `record`!
  end

  def admin_or_contract_signee?
    user&.admin? || OrganizerPosition.find_by(user:, event: record.event)&.is_signee
  end

end
