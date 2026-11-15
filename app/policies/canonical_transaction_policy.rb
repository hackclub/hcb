# frozen_string_literal: true

class CanonicalTransactionPolicy < ApplicationPolicy
  def show?
    auditor_or_teammember
  end

  def set_category?
    user&.admin?
  end

  def waive_fee?
    user&.admin?
  end

  def unwaive_fee?
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

  private

  def auditor_or_teammember
    user&.auditor? || record&.event&.users&.include?(user)
  end

end
