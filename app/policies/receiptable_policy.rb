# frozen_string_literal: true

class ReceiptablePolicy < ApplicationPolicy
  def upload?
    user&.admin? || present_in_events? || Pundit.policy(user, authorizable).try(:receiptable_upload?)
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

  # A transaction's receipts are attached to its ledger item
  # (https://github.com/hackclub/hcb/issues/14106), but who may upload them is
  # still the HCB code's call: the people on the transaction (the cardholder,
  # say) may upload without being members of the organization, and a code can
  # span more than one event. An item nothing has mapped to yet has no code and
  # falls back to its primary ledger's event.
  def authorizable
    return @authorizable if defined?(@authorizable)

    @authorizable = record.is_a?(::Ledger::Item) ? (record.hcb_code || record) : record
  end

  def present_in_events?
    return false if authorizable.nil?

    # Ledger::Item deliberately has no generic `event`/`events` method (it can be
    # mapped onto more than one ledger), so resolve its event the same way
    # Ledger::ItemPolicy does instead of assuming a single association.
    events =
      if authorizable.is_a?(::Ledger::Item)
        [authorizable.primary_ledger&.event || authorizable.primary_ledger&.card_grant&.event]
      else
        authorizable.try(:events) || [authorizable.event]
      end

    events.compact.any? { |event| OrganizerPosition.role_at_least?(user, event, :member) }
  end

end
