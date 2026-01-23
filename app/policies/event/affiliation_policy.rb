# frozen_string_literal: true

class Event
  class AffiliationPolicy < ApplicationPolicy
    def create?
      return OrganizerPosition.role_at_least?(user, record, :manager) if record.is_a?(Event)
    end

    def update?
      return OrganizerPosition.role_at_least?(user, record.affiliable, :manager) if record.affiliable.is_a?(Event)
    end

    def destroy?
      return OrganizerPosition.role_at_least?(user, record.affiliable, :manager) if record.affiliable.is_a?(Event)
    end

  end

end
