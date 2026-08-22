# frozen_string_literal: true

class Contract
  class PartyPolicy < ApplicationPolicy
    def show?
      if record.user.present?
        return true if record.role == "hcb" && user&.admin?

        return record.user == user
      end

      true
    end

    def resend?
      return user&.admin? if record.hcb?

      # Self-service: the contract's own signee/organizer can resend to any
      # non-HCB party on their own contract without changing anything. To
      # restrict this back to admins only, drop the `|| ...` clause below.
      user&.admin? || record.contract.owned_by?(user)
    end

    alias_method :completed?, :show?

  end

end
