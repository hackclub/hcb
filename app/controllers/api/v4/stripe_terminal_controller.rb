# frozen_string_literal: true

module Api
  module V4
    class StripeTerminalController < ApplicationController
      skip_after_action :verify_authorized, only: [:connection_token]

      def connection_token
        render json: {
          terminal_connection_token: Stripe::Terminal::ConnectionToken.create
        }
      end

    end
  end
end
