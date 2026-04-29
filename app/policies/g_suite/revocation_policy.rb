# frozen_string_literal: true

class GSuite
  class RevocationPolicy < ApplicationPolicy
    def create?
      admin?
    end

    def destroy?
      admin?
    end

  end

end
