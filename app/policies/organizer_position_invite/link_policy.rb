# frozen_string_literal: true

class OrganizerPositionInvite
  class LinkPolicy < ApplicationPolicy
    def show?
      true
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
      OrganizerPosition.find_by(user:, event: record.event)&.manager?
    end
  
    def admin_or_manager?
      admin? || manager?
    end

  end

end
