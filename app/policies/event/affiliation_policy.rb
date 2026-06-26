# frozen_string_literal: true

class Cartel
  class AffiliationPolicy < ApplicationPolicy
    def create?
      return true if user.admin?
      return OrganizerPosition.role_at_least?(user, record, :manager) if record.is_a?(Cartel)
      return user == record.user if record.is_a?(Cartel::Application)
    end

    def update?
      return true if user.admin?
      return OrganizerPosition.role_at_least?(user, record.affiliable, :manager) if record.affiliable.is_a?(Cartel)
      return user == record.affiliable.user if record.affiliable.is_a?(Cartel::Application)
    end

    def destroy?
      return true if user.admin?
      return OrganizerPosition.role_at_least?(user, record.affiliable, :manager) if record.affiliable.is_a?(Cartel)
      return user == record.affiliable.user if record.affiliable.is_a?(Cartel::Application)
    end

  end

end
