# frozen_string_literal: true

module Referral
  class ProgramPolicy < ApplicationPolicy
    def create?
      auditor?
    end

  end
end
