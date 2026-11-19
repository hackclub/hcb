# frozen_string_literal: true

class Announcement
  class BlockPolicy < ApplicationPolicy
    def create?
      admin_or_manager?
    end

    def show?
      admin_or_manager?
    end

    def edit?
      # Only the announcement's author may edit its blocks. We don't keep a
      # history of edits, so if another manager changed the content it would
      # still appear under the original author's name and misattribute their words.
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
      OrganizerPosition.role_at_least?(user, record.event, :manager)
    end

  end

end
