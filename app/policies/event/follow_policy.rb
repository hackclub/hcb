# frozen_string_literal: true

class Event
  class FollowPolicy < ApplicationPolicy
    def create?
      (record.event.is_public || OrganizerPosition.role_at_least?(user, record.event, :reader)) && user == record.user
    end

    def destroy?
      user == record.user
    end

  end

end
