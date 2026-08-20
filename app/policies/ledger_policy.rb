# frozen_string_literal: true

class LedgerPolicy < ApplicationPolicy
  def show?
    # Non-primary ledgers (e.g. a card grant's own ledger) aren't directly
    # tied to an event, so fall back to the event that owns the card grant.
    user&.auditor? || OrganizerPosition.role_at_least?(user, record.event || record.card_grant&.event, :reader)
  end

end
