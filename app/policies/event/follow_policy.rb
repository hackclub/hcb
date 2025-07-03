# frozen_string_literal: true

class Event
  class FollowPolicy < ApplicationPolicy
    def create?
      user == record.user && record.event.is_public
    end

    def destroy?
      user == record.user
    end
  end

end
