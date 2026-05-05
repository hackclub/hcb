# frozen_string_literal: true

class WebauthnCredentialPolicy < ApplicationPolicy
  def destroy?
    admin? || record.user == user
  end

end
