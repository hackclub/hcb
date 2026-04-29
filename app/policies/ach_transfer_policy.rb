# frozen_string_literal: true

class AchTransferPolicy < ApplicationPolicy
  def index?
    auditor?
  end

  def new?
    auditor_or_user?
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
    admin?
  end

  def approve?
    admin?
  end

  def reject?
    admin?
  end

  def toggle_speed?
    admin?
  end

  private

  def user_who_can_transfer?
    EventPolicy.new(user, record.event).create_transfer?
  end

  def auditor_or_user?
    auditor? || OrganizerPosition.role_at_least?(user, record.event, :reader)
  end

  def admin_or_user?
    admin? || OrganizerPosition.role_at_least?(user, record.event, :reader)
  end

  def admin_or_manager?
    admin? || OrganizerPosition.role_at_least?(user, record.event, :manager)
  end

  def is_public?
    record.event.is_public?
  end

end
