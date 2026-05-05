# frozen_string_literal: true

class Contract
  class PartyPolicy < ApplicationPolicy
    def show?
      if record.user.present?
        return true if record.role == "hcb" && admin?

        return record.user == user
      end

      true
    end

    def resend?
      admin?
    end

    alias_method :completed?, :show?

  end

end
