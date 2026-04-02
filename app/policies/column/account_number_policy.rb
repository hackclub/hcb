# frozen_string_literal: true

module Column
  class AccountNumberPolicy < ApplicationPolicy
    def create?
      user&.auditor? || OrganizerPosition.role_at_least?(user, record.event, :manager)
    end

    def update?
      user&.admin?
    end

  end

end
