# frozen_string_literal: true

class DisbursementPolicy < ApplicationPolicy
  def show?
    user.auditor?
  end

  def can_send?(role: :manager)
    return true if user&.admin?
    return true if record.source_event.nil?
    return true if OrganizerPosition.role_at_least?(user, record.source_event, role)

    false
  end

  def can_receive?(role: :manager)
    return true if user&.admin?
    return true if record.source_event&.plan&.unrestricted_disbursements_enabled?
    return true if record.destination_event.nil?
    return true if OrganizerPosition.role_at_least?(user, record.destination_event, role)

    false
  end

  def new?
    can_send?(role: :reader) && can_receive?(role: :reader)
  end

  def create?
    can_send? && can_receive?
  end

  def transfer_confirmation_letter?
    auditor_or_user?
  end

  def edit?
    user.admin?
  end

  def update?
    user.admin?
  end

  def cancel?
    user.admin?
  end

  def mark_fulfilled?
    user.admin?
  end

  def reject?
    user.admin?
  end

  def pending_disbursements?
    user.admin?
  end

  def set_transaction_categories?
    user.admin?
  end

  private

  def auditor_or_user?
    user&.auditor? || record.event.users.include?(user)
  end

end
