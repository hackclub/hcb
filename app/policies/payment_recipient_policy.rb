# frozen_string_literal: true

class PaymentRecipientPolicy < ApplicationPolicy
  def show?
    OrganizerPosition.role_at_least?(user, record.event, :member)
  end

  def destroy?
    OrganizerPosition.role_at_least?(user, record.event, :member)
  end

end
