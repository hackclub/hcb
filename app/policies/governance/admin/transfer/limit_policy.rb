# frozen_string_literal: true

module Governance
  module Admin
    module Transfer
      class LimitPolicy < ApplicationPolicy
        def update?
          # Mirrors `superadmin_signed_in?`: an admin impersonating a superadmin
          # must not inherit the ability to change transfer limits.
          user&.superadmin? && !Current.session&.impersonated?
        end

        def history?
          user&.admin?
        end

      end
    end
  end
end
