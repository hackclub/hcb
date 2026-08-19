# frozen_string_literal: true

class LedgerPolicy < ApplicationPolicy
  def show?
    user&.auditor? || Flipper.enabled?(:new_ledger_2026_07_17, user)
  end

end
