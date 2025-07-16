# frozen_string_literal: true

class Event
  class FollowPolicy < ApplicationPolicy
    def create?
      user == record.user
    end

    def destroy?
      user == record.user
    end

  end

end
