# frozen_string_literal: true

class Event
  class FollowPolicy < ApplicationPolicy
    def create?
      user == record.user && Flipper.enabled?(:organization_announcements_tier_1_2025_07_07, record.event)
    end

    def destroy?
      user == record.user
    end

  end

end
