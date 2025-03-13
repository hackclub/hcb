# frozen_string_literal: true

class CardGrantPolicy < ApplicationPolicy
  def new?
    admin_or_manager?
  end

  def create?
    admin_or_manager? && Flipper.enabled?(:card_grants_2023_05_25, record.event)
  end

  def show?
    user&.admin? || record.user == user || user_in_event?
  end

  def spending?
    record.event.is_public? || user&.admin? || user_in_event?
  end

  def activate?
    user&.admin? || record.user == user
  end

  def cancel?
    admin_or_user || record.user == user
  end

  def topup?
    admin_or_manager? && record.active?
  end

  def update?
    admin_or_manager?
  end

  def admin_or_user
    user&.admin? || record.event.users.include?(user)
  end

  def admin_or_manager?
    user&.admin? || OrganizerPosition.find_by(user:, event: record.event)&.manager?
  end

  private

  def user_in_event?
    record.event.users.include?(user)
  end

end
