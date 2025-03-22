# frozen_string_literal: true

class PaymentRecipientPolicy < ApplicationPolicy
  def destroy?
    OrganizerPosition.role_at_least?(user, :member)
  end

end
