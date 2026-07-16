# frozen_string_literal: true

class PaymentPolicy < ApplicationPolicy
  def show?
    return true if user&.auditor?
    return true if user.present? && record.legal_entity&.users&.exists?(id: user.id)

    user.present? && record.event.users.exists?(id: user.id)
  end

  # The new-payment form is part of moving money, so it's gated like create —
  # readers can view the payments list, but not this page.
  def new?
    create?
  end

  def create?
    EventPolicy.new(user, record).create_payment?
  end

end
