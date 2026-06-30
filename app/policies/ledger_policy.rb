# frozen_string_literal: true

class LedgerPolicy < ApplicationPolicy
  def show?
    user&.auditor? || (Flipper.enabled?(:new_ledger_2026_06_30) && OrganizerPosition.role_at_least?(user, record.event, :reader))
  end

end
