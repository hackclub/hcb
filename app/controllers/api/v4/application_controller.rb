# frozen_string_literal: true

module Api
  module V4
    class ApplicationController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods
      include Pundit::Authorization
      include PublicActivity::StoreController
      include ErrorHandling
      include AdminScopeCheckable
      include Pagination

      attr_reader :current_user

      after_action :verify_authorized

      before_action :authenticate!
      before_action :set_expand
      before_action :set_paper_trail_whodunnit

      def not_found
        skip_authorization
        render json: { error: "not_found" }, status: :not_found
      end

      def self.require_oauth2_scope(required_scope, *actions)
        @oauth_requirements ||= Hash.new { |h, k| h[k] = [] }

        actions.each { |action| @oauth_requirements[action.to_sym] << required_scope }
      end

      append_before_action :check_restricted_scopes!

      private

      def pundit_user
        current_user && ApiAdminContext.new(current_user, current_token)
      end

      def authorize(record, query = nil, policy_class: nil)
        authorized_record = super
        enforce_object_scope!(authorized_record)
        authorized_record
      end

      def enforce_object_scope!(record)
        return unless current_token

        access_level = request.get? || request.head? ? "read" : "write"
        resource_type = record.class.api_resource_type

        raise Pundit::NotAuthorizedError unless current_token.permits_object?(access_level, resource_type, record)
      end

      def authenticate!
        @current_token = authenticate_with_http_token { |t, _options| ApiToken.find_by(token: t) }
        unless @current_token&.accessible?
          return render json: { error: "invalid_auth" }, status: :unauthorized
        end

        @current_user = current_token&.user
      end

      def require_admin_scope!(level, resource: nil, record: nil)
        unless can_admin?(level, resource:, record:)
          skip_authorization
          render json: { error: "not_authorized" }, status: :forbidden
        end
      end

      def require_trusted_oauth_app!
        unless current_token&.application&.trusted?
          render json: { error: "not_authorized" }, status: :forbidden
        end
      end

      def check_restricted_scopes!
        # only check scopes for tokens that have the "restricted" scope so as not to break existing apps
        # this can roll out to all tokens later
        return unless current_token&.scopes&.include?("restricted")

        required_scopes = self.class.instance_variable_get(:@oauth_requirements)&.[](action_name.to_sym) || []

        # restricted tokens shouldn't work on actions without explicit scopes (most of them)
        if required_scopes.empty?
          raise Pundit::NotAuthorizedError
        end

        current_scopes = current_token.scopes || []
        has_required_scopes = required_scopes.all? { |scope| current_scopes.include?(scope) }

        raise Pundit::NotAuthorizedError unless has_required_scopes
      end

      def set_expand
        @expand = params[:expand].to_s.split(",").map { |e| e.strip.to_sym }
      end

      attr_reader :current_token

    end
  end
end
