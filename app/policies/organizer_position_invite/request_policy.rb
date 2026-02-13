# frozen_string_literal: true

class OrganizerPositionInvite
  class RequestPolicy < ApplicationPolicy
    def create?
      record.requester == user && record.link.active?
    end

    def approve?
      admin_or_manager?
    end

    def deny?
      admin_or_manager? || record.requester == user
    end

    private

    def admin?
      user&.admin?
    end

    def manager?
      OrganizerPosition.role_at_least?(user, record.link.event, :manager)
    end

    def admin_or_manager?
      admin? || manager?
    end

  end

end
