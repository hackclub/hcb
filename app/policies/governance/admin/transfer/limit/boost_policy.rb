# frozen_string_literal: true

module Governance
  module Admin
    module Transfer
      class Limit
        class BoostPolicy < ApplicationPolicy
          def create?
            superadmin_not_impersonated?
          end

          def revoke?
            superadmin_not_impersonated?
          end

          private

          def superadmin_not_impersonated?
            user&.superadmin? && !Current.session&.impersonated?
          end

        end

      end
    end
  end
end
