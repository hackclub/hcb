# frozen_string_literal: true

class OrganizerPositionPolicy < ApplicationPolicy
  # v3 publishes a transparent organization's user list, so the roster follows
  # the organization's own visibility. Which of each organizer's fields are
  # returned is UserPolicy's call.
  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(event: Event.visible_to(user))
    end

  end

  def destroy?
    admin_or_contract_signee?
  end

  def set_index?
    record.user == user
  end

  def mark_visited?
    record.user == user
  end

  def change_position_role?
    return false unless user
    return false if record.user == user && !admin_or_manager?
    return false if record.signee?

    admin_or_manager?
  end

  def can_request_removal?
    admin_or_manager? || record.user == user
  end

  def view_allowances?
    admin_or_manager? || record.user == user || user&.auditor?
  end


  # See ApplicationPolicy#visible_attributes. v3 publishes a transparent
  # organization's user list, so membership and role are public there. Whether
  # any given organizer's name or email is visible is UserPolicy's call, not
  # this one's.
  def visible_attributes
    @visible_attributes ||= begin
      attrs = []
      attrs += %i[role user user_id] if transparent_or_reader?
      attrs << :signee if event_reader? || !!user&.auditor?
      attrs
    end
  end

  private

  def admin_or_manager?
    user&.admin? ||
      OrganizerPosition.role_at_least?(user, record.event, :manager) # This is not just `record`!
  end

  def admin_or_contract_signee?
    user&.admin? || OrganizerPosition.find_by(user:, event: record.event)&.is_signee
  end

end
