# frozen_string_literal: true

class Contract
  class PartyPolicy < ApplicationPolicy
    def show?
      if record.user.present?
        return record.user == user
      end

      true
    end

    def resend?
      user&.admin?
    end

    alias_method :completed?, :show?

  end

end
