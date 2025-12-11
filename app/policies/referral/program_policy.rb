# frozen_string_literal: true

module Referral
  class ProgramPolicy < ApplicationPolicy
    def create?
      user.admin?
    end

  end
end
