# frozen_string_literal: true

module Api
  module V4
    module AdminScopeCheckable
      extend ActiveSupport::Concern

      # Returns true if the current token carries the given admin scope AND the
      # current user has the corresponding role.
      #
      #   :read  → token has "admin:read"  scope AND user is an auditor (auditors, admins, superadmins)
      #   :write → token has "admin:write" scope AND user is an admin (admins, superadmins)
      def can_admin?(level)
        return false unless current_token&.scopes&.include?("admin:#{level}")

        case level.to_sym
        when :read  then current_user&.auditor?
        when :write then current_user&.admin?
        else false
        end
      end
    end
  end
end
