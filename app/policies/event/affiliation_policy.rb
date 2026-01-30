# frozen_string_literal: true

class Event
  class AffiliationPolicy < ApplicationPolicy
    def create?
      return true if user.admin?
      return OrganizerPosition.role_at_least?(user, record, :manager) if record.is_a?(Event)
      return user == record.user if record.is_a?(Event::Application)
    end

    def update?
      return true if user.admin?
      return OrganizerPosition.role_at_least?(user, record.affiliable, :manager) if record.affiliable.is_a?(Event)
      return user == record.user if record.is_a?(Event::Application)
    end

    def destroy?
      return true if user.admin?
      return OrganizerPosition.role_at_least?(user, record.affiliable, :manager) if record.affiliable.is_a?(Event)
      return user == record.user if record.is_a?(Event::Application)
    end

  end

end
