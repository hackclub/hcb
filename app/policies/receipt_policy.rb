# frozen_string_literal: true

class ReceiptPolicy < ApplicationPolicy
  def destroy?
    user&.admin? ||
      (record&.receiptable&.event &&
        OrganizerPosition.role_at_least?(user, record.receiptable.event, :member) &&
        unlocked?
      ) ||
      # Checking if receiptable is nil prevents unauthorized
      # deletion when user no longer has access to an org
      (record&.receiptable.nil? && record&.user == user) ||
      (record&.receiptable.instance_of?(Reimbursement::Expense) && record&.user == user && unlocked?) ||
      (user && record&.receiptable.try(:card_grant)&.user == user && record.receiptable.card_grant.active?)
  end

  def destroy?  
    return true if user.admin?
    return false if record.nil?
    
    # any members of events should be able to modify receipts.
    if record.receiptable.event
      return true if OrganizerPosition.role_at_least?(user, record.receiptable.event, :member) && unlocked?
    end
    
    # the receipt is in receipt bin.
    if record.receiptable.nil?
      return record.user == user
    end
    
    # the receipt is on a reimbursement report. people making reports may not be in the organization.
    if record.receiptable.instance_of?(Reimbursement::Expense)
      return true if record.receiptable.report.user == user && unlocked?
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
