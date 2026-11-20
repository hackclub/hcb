# frozen_string_literal: true

class IncreaseCheckPolicy < ApplicationPolicy
  def new?
    auditor_or_user?
  end

  def create?
    user_who_can_transfer?
  end

  def update?
    user&.admin? && record.pending? && record.payment_attempt.nil? && record.employee_payment.nil?
  end

  def approve?
    user&.admin?
  end

  def stop?
    user_who_can_transfer? && record.can_stop?
  end

  def reject?
    user_who_can_transfer?
  end

  private

  def auditor_or_user?
    user&.auditor? || OrganizerPosition.role_at_least?(user, record.event, :reader)
  end

  def user_who_can_transfer?
    EventPolicy.new(user, record.event).create_transfer?
  end

end
