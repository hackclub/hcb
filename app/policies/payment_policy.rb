# frozen_string_literal: true

class PaymentPolicy < ApplicationPolicy
  def show?
    return true if user&.auditor?
    return true if user.present? && record.legal_entity&.users&.exists?(id: user.id)

    user.present? && record.event.users.exists?(id: user.id)
  end

  def new?
    EventPolicy.new(user, record).new_payment?
  end

  def create?
    EventPolicy.new(user, record).create_payment?
  end

  def cancel?
    EventPolicy.new(user, record.event).create_payment?
  end

  def retry?
    EventPolicy.new(user, record.event).create_payment?
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
