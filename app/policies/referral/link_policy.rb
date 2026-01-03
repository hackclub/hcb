# frozen_string_literal: true

module Referral
  class LinkPolicy < ApplicationPolicy
    def show?
      user.present?
    end

  end
end
