# frozen_string_literal: true

class StripeAuthorization
  class CreateFromWebhookForcedJob < ApplicationJob
    queue_as :critical
    def perform(stripe_transaction_id)
      ::StripeAuthorizationService::CreateFromWebhookForced.new(stripe_transaction_id:).run
    end

  end

end
