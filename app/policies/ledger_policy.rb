# frozen_string_literal: true

class LedgerPolicy < ApplicationPolicy
  def show?
    user&.auditor? || OrganizerPosition.role_at_least?(user, record.event || record.card_grant&.event, :reader)
  end

end
