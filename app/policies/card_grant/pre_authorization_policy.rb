# frozen_string_literal: true

class CardGrant
  class PreAuthorizationPolicy < ApplicationPolicy
    def show?
      user&.auditor? || record.user == user || user_in_event?
    end

    def update?
      user&.admin? || record.user == user || user_in_event?
    end

    def clear_screenshots?
      user&.auditor? || record.user == user || user_in_event?
    end

    def organizer_approve?
      user&.admin? || manager_in_event?
    end

    def organizer_reject?
      user&.admin? || manager_in_event?
    end

    private

    def user_in_event?
      OrganizerPosition.role_at_least?(user, record.event, :reader)
    end

    def manager_in_event?
      OrganizerPosition.role_at_least?(user, record.event, :manager)
    end

  end

end
