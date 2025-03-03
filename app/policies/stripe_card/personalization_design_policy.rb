# frozen_string_literal: true

class StripeCard
  class PersonalizationDesignPolicy < ApplicationPolicy
    def show?
      user&.admin?
    end

    def make_common?
      user&.admin?
    end

    def make_unlisted?
      user&.admin?
    end

  end

end
