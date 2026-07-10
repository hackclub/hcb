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

    alias_method :switch_legal_entity?, :sync?
    alias_method :create_legal_entity?, :sync?
    alias_method :discard?, :sync?

  end
end
