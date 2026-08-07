# frozen_string_literal: true

class OrganizerPositionInvite
  class LinkPolicy < ApplicationPolicy
    def index?
      admin_or_manager?
    end

    def show?
      true
    end

    def new?
      admin_or_manager?
    end

    def create?
      admin_or_manager?
    end

    def deactivate?
      admin_or_manager?
    end

    private

    def admin?
      user&.admin?
    end

    def manager?
      OrganizerPosition.role_at_least?(user, record.event, :manager)
    end

    def admin_or_manager?
      admin? || manager?
    end

  end

end
