# frozen_string_literal: true

class WiseTransferPolicy < ApplicationPolicy
  def new?
    admin_or_user?
  end

  def create?
    user_who_can_transfer?
  end

  def approve?
    user&.admin?
  end

  def reject?
    user_who_can_transfer?
  end

  def update?
    user&.admin?
  end

  def mark_sent?
    user&.admin?
  end

  def mark_failed?
    user_who_can_transfer?
  end

  def generate_quote?
    user&.auditor? || user.events.any?
  end

  private

  def admin_or_user?
    user&.admin? || OrganizerPosition.role_at_least?(user, record.event, :reader)
  end

  def user_who_can_transfer?
    EventPolicy.new(user, record.event).create_transfer? && Flipper.enabled?(:wise_transfers_2025_07_31, user)
  end

end
