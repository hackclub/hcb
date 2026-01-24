# frozen_string_literal: true

module Api
  module V4
    class IntercomController < ApplicationController
      skip_after_action :verify_authorized, only: [:token]
      before_action :require_trusted_oauth_app!, only: [:token]

      def token
        payload = {
          user_id: current_user.public_id,
          email: current_user.email,
          exp: 1.hour.from_now.to_i
        }

        token = JWT.encode(payload, Credentials.fetch(:INTERCOM, :API_SECRET), "HS256")

        render json: { token: token }
      end

    end
  end
end
