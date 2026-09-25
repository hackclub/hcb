# frozen_string_literal: true

module Tax
  class FormPolicy < ApplicationPolicy
    def show?
      record.legal_entity.present? && (user.auditor? || user_in_legal_entity?(record.legal_entity))
    end

    def create?
      user.admin? || user_in_legal_entity?(record)
    end

    def completed?
      record.legal_entity.present? && (user.admin? || user_in_legal_entity?(record.legal_entity))
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

    # An unclaimed form has no legal entity, so nobody's in it.
    def user_in_legal_entity?(le)
      le.present? && le.emails.include?(user.email)
    end

  end
end
