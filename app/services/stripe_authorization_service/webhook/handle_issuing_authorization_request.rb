# frozen_string_literal: true

module StripeAuthorizationService
  module Webhook
    class HandleIssuingAuthorizationRequest
      attr_reader :declined_reason

      def initialize(stripe_event:)
        @stripe_event = stripe_event
      end

      def run
        true
      end

    end
  end
end
