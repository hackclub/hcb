# frozen_string_literal: true

module Api
  module V4
    module AdminScopeCheckable
      extend ActiveSupport::Concern

      # True when the current token carries the required admin scope (or an
      # equivalent resource-limited scope/grant, see ApiAdminContext) AND the
      # current user holds the corresponding role.
      def can_admin?(level, resource: nil, record: nil)
        return false unless current_user

        ApiAdminContext.new(current_user, current_token).can_admin?(level, resource:, record:)
      end
    end
  end
end
