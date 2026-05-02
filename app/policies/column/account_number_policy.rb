# frozen_string_literal: true

module Column
  class AccountNumberPolicy < ApplicationPolicy
    def create?
      # Usually, we don't allow auditors to create. However, this is needed for account numbers because we create them on-demand during page load.
      user&.auditor? || OrganizerPosition.role_at_least?(user, record.event, :manager)
    end

    def update?
      user&.admin?
    end

  end

end
