# frozen_string_literal: true

class GSuite
  class RevocationPolicy < ApplicationPolicy
    def create?
      user.admin?
    end

    def destroy?
      user.admin?
    end

  end

end
