# frozen_string_literal: true

module Governance
  module Admin
    module Transfer
      class LimitPolicy < ApplicationPolicy
        def update?
          user&.superadmin?
        end

        def history?
          user&.admin?
        end
      end
    end
  end
end