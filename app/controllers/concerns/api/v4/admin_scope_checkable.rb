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
      #   :read  → token has "admin:read"  scope AND user is an auditor (auditors, admins, superadmins)
      #   :write → token has "admin:write" scope AND user is an admin (admins, superadmins)
      #
      # Pass `resource` to also accept a resource-scoped admin grant (e.g.
      # resource: "comments") in place of the blanket admin scope, and
      # `record` to further require that grant to cover this specific object
      # (see ApiToken::ResourceGrant).
      def can_admin?(level, resource: nil, record: nil)
        return false unless current_user

        context = ApiAdminContext.new(current_user, current_token)

        case level.to_sym
        when :read  then context.auditor?(resource:, record:)
        when :write then context.admin?(resource:, record:)
        else false
        end
      end
    end
  end
end
