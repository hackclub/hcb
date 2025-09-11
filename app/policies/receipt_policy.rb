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

  def link?
    record.receiptable.nil? && record.user == user
  end

  def reverse?
    record.user == user && unlocked?
  end

  def receipt_item?
    record.user == user
  end

  private

  def unlocked?
    !record&.receiptable.try(:locked)
  end

end
