# frozen_string_literal: true

class StripeAuthorization
  class CreateFromWebhookJob < ApplicationJob
    queue_as :critical
    def perform(stripe_transaction_id)
      ::StripeAuthorizationService::CreateFromWebhook.new(stripe_transaction_id:).run
    end

  end

end

module StripeAuthorizationJob
  CreateFromWebhook = StripeAuthorization::CreateFromWebhookJob
end
