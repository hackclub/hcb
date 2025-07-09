# frozen_string_literal: true

class AnnouncementPolicy < ApplicationPolicy
  def index?
    show?
  end

  def new?
    admin_or_manager? && !record.event.demo_mode?
  end

  def create?
    admin_or_manager? && !record.event.demo_mode?
  end

  def show?
    Flipper.enabled?(:organization_announcements_tier_1_2025_07_07, record.event)
  end

  def edit?
    admin? || record.author == user
  end

  def update?
    admin? || record.author == user
  end

  def destroy?
    admin_or_manager?
  end

  def publish?
    admin_or_manager?
  end

  private

  def admin?
    user&.admin?
  end

  def auditor?
    user&.auditor?
  end

  def manager?
    OrganizerPosition.find_by(user:, event: record.event)&.manager?
  end

  def reader?
    OrganizerPosition.role_at_least?(user, record, :reader)
  end

  def admin_or_manager?
    admin? || manager?
  end

  def auditor_or_reader?
    auditor? || reader?
  end

end
