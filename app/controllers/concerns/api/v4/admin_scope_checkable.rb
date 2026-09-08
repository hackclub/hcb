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
      def can_admin?(level)
        return false unless current_user

        context = ApiAdminContext.new(current_user, current_token)

        case level.to_sym
        when :read  then context.auditor?
        when :write then context.admin?
        else false
        end
      end
    end
  end
end
