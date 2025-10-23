# frozen_string_literal: true

class Event
  class ScopedTagPolicy < ApplicationPolicy
    def create?
      admin_or_manager?
    end

    def update?
      admin_or_manager?
    end

    def destroy?
      admin_or_manager?
    end

    def toggle_tag?
      admin_or_manager?
    end

    private

    def admin_or_manager?
      user&.admin? || OrganizerPosition.role_at_least?(user, record.parent_event, :manager)
    end

  end

end
