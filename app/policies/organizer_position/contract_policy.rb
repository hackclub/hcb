# frozen_string_literal: true

class OrganizerPosition
  class ContractPolicy < ApplicationPolicy
    def create?
      user&.admin?
    end

    def void?
      user&.admin?
    end

  end

end
