# frozen_string_literal: true

class ReceiptablePolicy < ApplicationPolicy
  def upload?
    user&.admin? || present_in_events? || Pundit.policy(user, record).try(:receiptable_upload?)
  end

  def link?
    upload?
  end

  def link_modal?
    upload? || user&.auditor?
  end

  def mark_no_or_lost?
    upload?
  end

  private

  def present_in_events?
    return false if record.nil?

    # Ledger::Item deliberately has no generic `event`/`events` method (it can be
    # mapped onto more than one ledger), so look up its event the same way
    # Ledger::ItemPolicy#rename? does instead of assuming a single association.
    events =
      if record.is_a?(::Ledger::Item)
        [record.primary_ledger&.event]
      else
        record.try(:events) || [record.event]
      end

    events.compact.any? { |event| OrganizerPosition.role_at_least?(user, event, :member) }
  end

end
