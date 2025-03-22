# frozen_string_literal: true

class PaypalTransferPolicy < ApplicationPolicy
  def new?
    OrganizerPosition.role_at_least?(user, :member)
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

  def mark_failed?
    user&.admin?
  end

  private

  def user_who_can_transfer?
    EventPolicy.new(user, record.event).create_transfer?
  end

end
