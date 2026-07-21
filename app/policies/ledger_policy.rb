# frozen_string_literal: true

class LedgerPolicy < ApplicationPolicy
  def show?
    user&.auditor? || (OrganizerPosition.role_at_least?(user, record.event, :reader) && (Flipper.enabled?(:new_ledger_2026_06_30, record.event) || Flipper.enabled?(:new_ledger_2026_07_17, user)))
  end

end
