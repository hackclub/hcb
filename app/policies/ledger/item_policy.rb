# frozen_string_literal: true

class Ledger
  class ItemPolicy < ApplicationPolicy
    def show?
      if (ledger = record.primary_ledger)
        LedgerPolicy.new(user, record.primary_ledger).show?
      else
        # Item is unampped, only admins can see it
        user&.admin?
      end
    end

  end

end
