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

      private

      def current_user_record
        raise Pundit::NotAuthorizedError if current_user.nil?

        current_user
      end

    end
  end
end
