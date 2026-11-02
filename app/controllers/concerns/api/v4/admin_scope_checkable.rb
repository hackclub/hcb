# frozen_string_literal: true

module Api
  module V4
    module AdminScopeCheckable
      extend ActiveSupport::Concern

      # Returns true if the current token carries the given admin scope AND the
      # current user has the corresponding role. Delegates to ApiAdminContext
      # (the same object used as pundit_user) so the scope + role + "pretend not
      # to be an admin" handling stays identical between controller-level gates
      # and Pundit policies.
      #
      #   :read  → token has "admin:read"  (or "admin.<resource>:read")  scope AND user is an auditor
      #   :write → token has "admin:write" (or "admin.<resource>:write") scope AND user is an admin
      #
      # Pass `resource` to also accept the narrower "admin.<resource>:<level>" scope
      # (e.g. resource: "comments") alongside the blanket "admin:<level>" scope.
      def can_admin?(level, resource: nil)
        return false unless current_user

        context = ApiAdminContext.new(current_user, current_token)

        case level.to_sym
        when :read  then context.auditor?(resource: resource)
        when :write then context.admin?(resource: resource)
        else false
        end
      end
    end
  end
end
