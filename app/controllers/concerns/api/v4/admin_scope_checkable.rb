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
      # `scope` is an exact admin scope, e.g. "admin:read" or the
      # resource-scoped "admin:users:read". The blanket "admin:read" /
      # "admin:write" scopes always satisfy any resource-scoped requirement
      # of the same level (see ApiAdminContext#admin_scope?).
      #
      #   *:read  → token has the scope AND user is an auditor (auditors, admins, superadmins)
      #   *:write → token has the scope AND user is an admin (admins, superadmins)
      def can_admin?(scope)
        return false unless current_user

        *resource, level = scope.to_s.split(":")
        resource = resource.drop(1).join(":").presence # drop the leading "admin" segment

        context = ApiAdminContext.new(current_user, current_token, resource: resource)

        case level
        when "read"  then context.auditor?
        when "write" then context.admin?
        else false
        end
      end
    end
  end
end
