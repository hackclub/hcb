# frozen_string_literal: true

class ReceiptPolicy < ApplicationPolicy
  def destroy?
    return false if record.nil?
    return true if user&.admin?

    # the receipt is in receipt bin.
    if record.receiptable.nil?
      return record.user == user
    end

    # who may delete a receipt attached to a record is up to that record's own policy.
    Pundit.policy(user, record.receiptable).try(:receipt_destroy?) && unlocked?
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
