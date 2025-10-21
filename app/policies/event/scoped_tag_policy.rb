# frozen_string_literal: true

class Event
  class ScopedTagPolicy < ApplicationPolicy
    def create?
      OrganizerPosition.role_at_least?(user, record, :manager)
    end

    def update?
      OrganizerPosition.role_at_least?(user, record.parent_event, :manager)
    end

    def destroy?
      OrganizerPosition.role_at_least?(user, record.parent_event, :manager)
    end

    def toggle_tag?
      OrganizerPosition.role_at_least?(user, record.parent_event, :manager)
    end

  end

end
