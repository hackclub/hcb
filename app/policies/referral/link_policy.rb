# frozen_string_literal: true

module Referral
  class LinkPolicy < ApplicationPolicy
    def show?
      true
    end

    def create?
      auditor?
    end

  end
end
