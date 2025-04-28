# frozen_string_literal: true

class AchTransferPolicy < ApplicationPolicy
  def index?
    user&.auditor?
  end

  def new?
    admin_or_user?
  end

  def create?
    user_who_can_transfer? && !record.event.demo_mode
  end

  def show?
    # Semantically, this should be admin_or_manager?, right?
    is_public? || user_who_can_transfer?
  end

  def view_account_routing_numbers?
    admin_or_manager?
  end

  def cancel?
    user_who_can_transfer?
  end

  def transfer_confirmation_letter?
    user_who_can_transfer?
  end

  def start_approval?
    user&.admin?
  end

  def approve?
    user&.admin?
  end

  def reject?
    user&.admin?
  end

  def toggle_speed?
    user&.admin?
  end

  private

  def user_who_can_transfer?
    EventPolicy.new(user, record.event).create_transfer?
  end

  def admin_or_user?
    OrganizerPosition.role_at_least?(user, record.event, :member)
  end

  def admin_or_manager?
    user&.admin? || OrganizerPosition.find_by(user:, event: record.event)&.manager?
  end

  def is_public?
    record.event.is_public?
  end

end
