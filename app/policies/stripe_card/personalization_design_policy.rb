# frozen_string_literal: true

class StripeCard
  class PersonalizationDesignPolicy < ApplicationPolicy
    def show?
      auditor?
    end

    def make_common?
      admin?
    end

    def make_unlisted?
      admin?
    end

  end

end
