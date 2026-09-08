# frozen_string_literal: true

class LegalEntity
  class PayoutMethodPolicy < ApplicationPolicy
    def create?
      owns_legal_entity? || user.admin?
    end

    def update?
      owns_legal_entity? || user.admin?
    end

    def set_default?
      owns_legal_entity? || user.admin?
    end

    def archive?
      owns_legal_entity? || user.admin?
    end

    private

    def owns_legal_entity?
      user.legal_entities.include?(record.legal_entity)
    end

  end

end
