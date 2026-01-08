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
    if record.receiptable.event
      return OrganizerPosition.role_at_least?(user, record.receiptable.event, :member) && unlocked?
    end

    return false
  end

  def link?
    record.receiptable.nil? && record.user == user
  end

  def reverse?
    record.user == user && unlocked?
  end

  private

  def unlocked?
    !record&.receiptable.try(:locked)
  end

end
