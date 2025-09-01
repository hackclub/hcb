# frozen_string_literal: true

class Event
  class AffiliationPolicy < ApplicationPolicy
    def create?
      OrganizerPosition.role_at_least?(user, record, :manager)
    end

    def update?
      OrganizerPosition.role_at_least?(user, record.event, :manager)
    end

    def destroy?
      OrganizerPosition.role_at_least?(user, record.event, :manager)
    end

  end

end
