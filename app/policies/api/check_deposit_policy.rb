# frozen_string_literal: true

module Api
  class CheckDepositPolicy < ApplicationPolicy
    def show?
      record.event.is_public?
    end

  end

end
