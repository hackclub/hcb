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
    user&.auditor? || can_send?(role: :reader) && can_receive?(role: :reader)
  end

  alias event_search? new?

  def create?
    can_send? && can_receive?
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


  # See ApplicationPolicy#visible_attributes. v3's `transfer` entity publishes
  # the amount, date, status and the organizations on each end.
  def visible_attributes
    @visible_attributes ||= begin
      attrs = []
      attrs += %i[amount_cents status from to] if transparent_or_reader?
      attrs += %i[memo transaction_id outgoing_transaction_id incoming_transaction_id sender card_grant_id] if reader_on_either_end?
      attrs
    end
  end

  # A disbursement sits between two organizations and is visible from either.
  def transparent_or_reader?
    [record.source_event, record.destination_event].compact.any?(&:is_public?) || reader_on_either_end?
  end

  def reader_on_either_end?
    return true if user&.auditor?
    return false if user.nil?

    [record.source_event, record.destination_event].compact.any? { |e| user.readable_event_ids.include?(e.id) }
  end

end
