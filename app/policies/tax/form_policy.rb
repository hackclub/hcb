# frozen_string_literal: true

module Tax
  class FormPolicy < ApplicationPolicy
    def show?
      user.auditor? || record.legal_entity.users.include?(user)
    end

    def create?
      user.admin? || record.users.include?(user)
    end

    def sync?
      user.admin? || record.legal_entity.users.include?(user)
    end

  end
end
