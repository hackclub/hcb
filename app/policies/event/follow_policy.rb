# frozen_string_literal: true

class Event
  class FollowPolicy < ApplicationPolicy
    def create?
      Pundit.policy(record.event).announcement_overview? && user == record.user
    end

    def destroy?
      user == record.user || OrganizerPosition.role_at_least?(user, record.event, :manager)
    end

  end

end
