# frozen_string_literal: true

module Api
  module V5
    class ApplicationController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods
      include Pundit::Authorization
      include PublicActivity::StoreController
      # Reused from v4 rather than copied while v5 is a pilot; it will move to
      # a shared concern when v5 grows past one endpoint.
      include Api::V4::ErrorHandling
      include Api::V4::AdminScopeCheckable

      attr_reader :current_user, :current_token

      # Member actions authorize a record; index actions scope a relation.
      # Pundit verifies both, which is what removes the need for
      # `skip_authorization` in an index — the v4 pattern that disables the
      # safety net and leaves correctness to a hand-written controller scope.
      after_action :verify_authorized, except: :index
      after_action :verify_policy_scoped, only: :index

      before_action :authenticate
      before_action :set_paper_trail_whodunnit

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

    end
  end
end
