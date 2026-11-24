# frozen_string_literal: true

class EmburseTransactionPolicy < ApplicationPolicy
  def index?
    user&.auditor?
  end

  def show?
    user&.auditor? || OrganizerPosition.role_at_least?(user, record.event, :reader)
  end

  def edit?
    user&.admin?
  end

  def update?
    user&.admin?
  end

  # Who may attach receipts to this record, through ReceiptablePolicy.
  def receiptable_upload?
    user&.admin? || OrganizerPosition.role_at_least?(user, record.event, :member)
  end

  # Who may delete a receipt attached to this record, through ReceiptPolicy.
  def receipt_destroy?
    OrganizerPosition.role_at_least?(user, record.event, :member)
  end

end
