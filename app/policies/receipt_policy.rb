# frozen_string_literal: true

class ReceiptPolicy < ApplicationPolicy
  def destroy?
    return false if record.nil?
    return true if user&.admin?

    # the receipt is in receipt bin.
    if record.receiptable.nil?
      return record.user == user
    end

    # the receipt is on a reimbursement report. people making reports may not be in the organization.
    if record.receiptable.instance_of?(Reimbursement::Expense)
      return (record.receiptable.report.user == user || OrganizerPosition.role_at_least?(user, record.receiptable.event, :manager)) && unlocked?
    end

    # any members of events should be able to modify receipts.
    event = receiptable_event
    if event
      return OrganizerPosition.role_at_least?(user, event, :member) && unlocked?
    end

    return false
  end

  # undoing an automatic rotation
  def restore_original?
    destroy?
  end

  def link?
    record.receiptable.nil? && record.user == user
  end

  def reverse?
    record.user == user && unlocked?
  end

  private

  # Ledger::Item deliberately has no generic `event` method (it can be mapped
  # onto more than one ledger), so resolve its event the same way
  # Ledger::ItemPolicy does instead of assuming a single association.
  def receiptable_event
    receiptable = record.receiptable

    if receiptable.is_a?(::Ledger::Item)
      receiptable.primary_ledger&.event || receiptable.primary_ledger&.card_grant&.event
    else
      receiptable.event
    end
  end

  def unlocked?
    !record&.receiptable.try(:locked)
  end

end
