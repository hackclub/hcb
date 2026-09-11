# frozen_string_literal: true

module Api
  module V5
    class ApplicationController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods
      include Pundit::Authorization
      include PublicActivity::StoreController
      include Api::V5::ErrorHandling
      include Api::V5::AdminScopeCheckable
      include Api::V5::Pagination

      attr_reader :current_user, :current_token

      # Member actions authorize a record; index actions scope a relation.
      # Pundit verifies both, which is what removes the need for
      # `skip_authorization` in an index — the v4 pattern that disables the
      # safety net and leaves correctness to a hand-written controller scope.
      after_action :verify_authorized, except: :index
      after_action :verify_policy_scoped, only: :index

      before_action :authenticate
      before_action :set_expand
      before_action :set_paper_trail_whodunnit

      def not_found
        skip_authorization
        render json: { error: "not_found" }, status: :not_found
      end

      # Declares the OAuth scopes an action requires. Enforced only for tokens
      # that carry "restricted", same as v4 — see dev-docs/v4-api/scopes.md.
      def self.require_oauth2_scope(required_scope, *actions)
        @oauth_requirements ||= Hash.new { |h, k| h[k] = [] }

        actions.each { |action| @oauth_requirements[action.to_sym] << required_scope }
      end

      append_before_action :check_restricted_scopes!

      private

      def pundit_user
        current_user && ApiAdminContext.new(current_user, current_token)
      end

      # Unlike v4, v5 permits anonymous requests: transparent organizations are
      # public (v3 parity), and policies already treat a nil user as "signed
      # out" rather than erroring. A token that is *present but bad* is still
      # rejected — only its absence is allowed through.
      def authenticate
        return if request.authorization.blank?

        @current_token = authenticate_with_http_token { |t, _options| ApiToken.find_by(token: t) }

        unless @current_token&.accessible?
          return render json: { error: "invalid_auth" }, status: :unauthorized
        end

        @current_user = @current_token.user
      end

      def check_restricted_scopes!
        return unless current_token&.scopes&.include?("restricted")

        required_scopes = self.class.instance_variable_get(:@oauth_requirements)&.[](action_name.to_sym) || []

        raise Pundit::NotAuthorizedError if required_scopes.empty?

        current_scopes = current_token.scopes || []
        raise Pundit::NotAuthorizedError unless required_scopes.all? { |scope| current_scopes.include?(scope) }
      end

      def set_expand
        @expand = params[:expand].to_s.split(",").map { |e| e.strip.to_sym }
      end

      def require_admin_scope!(level)
        unless can_admin?(level)
          skip_authorization
          render json: { error: "not_authorized" }, status: :forbidden
        end
      end

      def require_trusted_oauth_app!
        unless current_token&.application&.trusted?
          render json: { error: "not_authorized" }, status: :forbidden
        end
      end

    end
  end
end
