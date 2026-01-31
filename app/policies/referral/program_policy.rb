# frozen_string_literal: true

module Referral
  class ProgramPolicy < ApplicationPolicy
    def create?
      user.auditor?
    end

  end
end
