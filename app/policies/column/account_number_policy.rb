# frozen_string_literal: true

module Column
  class AccountNumberPolicy < ApplicationPolicy
    def create?
      admin_or_manager?
    end

    def update?
      user&.admin?
    end

    private

    def admin_or_manager?
      user&.admin? || OrganizerPosition.role_at_least?(user, record.event, :manager)
    end

  end

end
