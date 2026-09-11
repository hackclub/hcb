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


  # See ApplicationPolicy#visible_attributes. Receipts are documents attached to
  # a transaction; v3 publishes only whether one is *missing*, never the file,
  # so there is no public tier. ReceiptPolicy has no `show?` — visibility is
  # spelled out here rather than inherited from ApplicationPolicy's `false`,
  # which would have silently emptied every receipt.
  def visible_attributes
    @visible_attributes ||= begin
      attrs = []
      attrs += %i[url preview_url filename uploader uploader_id] if viewable?
      attrs
    end
  end

  # A receipt in the bin belongs to its uploader alone; one attached to a
  # transaction follows that transaction's organization.
  def viewable?
    return true if !!user&.auditor?
    return false if user.nil?
    return record.user == user if record.receiptable.nil?

    event_reader? || record.user == user
  end

  def policy_event
    record.try(:receiptable).try(:event)
  end

  private

  def unlocked?
    !record&.receiptable.try(:locked)
  end

end
