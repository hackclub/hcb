# frozen_string_literal: true

module Column
  class AccountNumberPolicy < ApplicationPolicy
    def create?
      admin_or_manager
    end

    def update?
      user&.admin?
    end

    private

    def admin_or_manager
      user&.admin? || OrganizerPosition.find_by(user:, event: record.event)&.manager?
    end

  end

end
