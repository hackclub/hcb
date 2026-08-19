# frozen_string_literal: true

class Ledger
  class ItemPolicy < ApplicationPolicy
    def show?
      if record.primary_ledger
        LedgerPolicy.new(user, record.primary_ledger).show?
      else
        # Item is unampped, only admins can see it
        user&.admin?
      end
    end

    alias_method :hcb?, :show?
    alias_method :pin?, :show?
    alias_method :unpin?, :show?

  end

end
