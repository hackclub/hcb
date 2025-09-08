# frozen_string_literal: true

class Announcement
  class BlockPolicy < ApplicationPolicy
    def create?
      admin_or_manager?
    end

    def show?
      admin_or_manager?
    end

    def refresh?
      admin_or_manager?
    end

    def edit?
      (manager? && record.announcement.author == user) || admin?
    end

    def update?
      edit?
    end

    private

    def admin_or_manager?
      admin? || manager?
    end

    def admin?
      user&.admin?
    end

    def manager?
      OrganizerPosition.find_by(user:, event: record.event)&.manager?
    end

  end

end
