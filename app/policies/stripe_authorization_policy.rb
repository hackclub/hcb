# frozen_string_literal: true

class StripeAuthorizationPolicy < ApplicationPolicy
  # Who may attach receipts to this record, through ReceiptablePolicy.
  def receiptable_upload?
    user&.admin? || OrganizerPosition.role_at_least?(user, record.event, :member)
  end

  # Who may delete a receipt attached to this record, through ReceiptPolicy.
  def receipt_destroy?
    OrganizerPosition.role_at_least?(user, record.event, :member)
  end

end
