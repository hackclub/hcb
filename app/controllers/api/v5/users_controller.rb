# frozen_string_literal: true

module Api
  module V5
    class UsersController < ApplicationController
      def me
        @user = authorize current_user_record, :show_any_attribute?
      end

      require_oauth2_scope "profile:read", :me

      def show
        @user = authorize User.find_by_public_id!(params[:id]), :show_any_attribute?
      end

      require_oauth2_scope "profile:read", :show

      # Revoking is an action on the token, not on a user record — there is no
      # record to authorize, and a caller can only ever revoke the token it is
      # presenting.
      def revoke
        skip_authorization
        current_token.update!(revoked_at: Time.current)

        render json: { message: "Token revoked", owner_email: current_user.email,
                       key_name: current_token.application&.name }
      end

      private

      def current_user_record
        raise Pundit::NotAuthorizedError if current_user.nil?

        current_user
      end

    end
  end
end
