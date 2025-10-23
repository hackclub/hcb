# frozen_string_literal: true

module Referral
  class ProgramPolicy < ApplicationPolicy
    def show
      user.present?
    end

  end
end
