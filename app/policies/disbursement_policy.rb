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
    # Anyone can send to a transparent organization, listed or not; private
    # organizations still require a role.
    return true if record.destination_event.accepts_public_transfers?
    return true if OrganizerPosition.role_at_least?(user, record.destination_event, role)

    false
  end

  def new?
    user&.auditor? || can_send?(role: :reader) && can_receive?(role: :reader)
  end

  alias event_search? new?

  # Picking a transaction to repay means browsing the destination's ledger,
  # which is public for transparent organizations (see EventPolicy#ledger?).
  def repay?
    record.destination_event&.is_public? || OrganizerPosition.role_at_least?(user, record.destination_event, :reader)
  end

  def create?
    # `can_send?` allows a missing source so `new?` can render a blank form,
    # but a transfer can't be created without one.
    record.source_event.present? && can_send? && can_receive?
  end

  def transfer_confirmation_letter?
    auditor_or_user?
  end

  def edit?
    user&.admin?
  end

  def update?
    user&.admin?
  end

  def cancel?
    user&.admin?
  end

  def mark_fulfilled?
    user&.admin?
  end

  def approve?
    user&.admin?
  end

  def reject?
    user&.admin?
  end

  def pending_disbursements?
    user&.admin?
  end

  def set_transaction_categories?
    user&.admin?
  end

  private

  def auditor_or_user?
    user&.auditor? || OrganizerPosition.role_at_least?(user, record.event, :reader)
  end

end
