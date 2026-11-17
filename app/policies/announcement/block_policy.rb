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
      # Blocks inside HCB-generated (prompted & monthly) announcements are editable by any manager, matching AnnouncementPolicy#edit?
      (manager? && (record.announcement.author == user || record.announcement.author == User.system_user)) || admin?
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
