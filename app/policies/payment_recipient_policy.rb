# frozen_string_literal: true

class PaymentRecipientPolicy < ApplicationPolicy
  def destroy?
    OrganizerPosition.role_at_least?(user, record.event, :member)
  end

end
