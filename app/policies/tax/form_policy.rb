# frozen_string_literal: true

module Tax
  class FormPolicy < ApplicationPolicy
    def show?
      user.auditor? || user_in_legal_entity?(record.legal_entity)
    end

    def create?
      user.admin? || user_in_legal_entity?(record)
    end

    def sync?
      user.admin? || user_in_legal_entity?(record.legal_entity)
    end

    def create_legal_entity?
      user_in_legal_entity?(record.legal_entity)
    end

    def switch_legal_entity?
      user_in_legal_entity?(record.legal_entity)
    end

    def discard?
      user_in_legal_entity?(record.legal_entity)
    end

    private

    def user_in_legal_entity?(le)
      le.emails.include?(user.email)
    end

  end
end
