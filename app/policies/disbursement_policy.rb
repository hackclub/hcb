# frozen_string_literal: true

class DisbursementPolicy < ApplicationPolicy
  def show?
    auditor?
  end

  def can_send?(role: :manager)
    return true if admin?
    return true if record.source_event.nil?
    return true if OrganizerPosition.role_at_least?(user, record.source_event, role)

    false
  end

  def can_receive?(role: :manager)
    return true if admin?
    return true if record.source_event&.plan&.unrestricted_disbursements_enabled?
    return true if record.destination_event.nil?
    return true if OrganizerPosition.role_at_least?(user, record.destination_event, role)

    false
  end

  def new?
    auditor? || can_send?(role: :reader) && can_receive?(role: :reader)
  end

  def create?
    can_send? && can_receive?
  end

  def transfer_confirmation_letter?
    auditor_or_user?
  end

  def edit?
    admin?
  end

  def update?
    admin?
  end

  def cancel?
    admin?
  end

  def mark_fulfilled?
    admin?
  end

  def reject?
    admin?
  end

  def pending_disbursements?
    admin?
  end

  def set_transaction_categories?
    admin?
  end

  private

  def auditor_or_user?
    auditor? || OrganizerPosition.role_at_least?(user, record.event, :reader)
  end

end
