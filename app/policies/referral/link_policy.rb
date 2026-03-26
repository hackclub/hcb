# frozen_string_literal: true

module Referral
  class LinkPolicy < ApplicationPolicy
    def show?
      user.present?
    end

    def create?
      user.auditor?
    end

  end
end
