# frozen_string_literal: true

module Referral
  class ProgramPolicy < ApplicationPolicy
    def create?
      true
    end

  end
end
