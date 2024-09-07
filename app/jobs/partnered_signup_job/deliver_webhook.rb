# frozen_string_literal: true

module PartneredSignupJob
  class DeliverWebhook < ApplicationJob
    queue_as :default
    WebhookFailed = Class.new(StandardError)

    retry_on WebhookFailed, wait: :polynomially_longer, attempts: 16
    # polynomially_longer uses this algorithm to determine the wait between retries: (attempts ^ 4) + 2
    # 16 attempts will take roughly 3 days to complete (following Stripe: https://stripe.com/docs/webhooks/best-practices#retry-logic)
    # ∑((n^4)+2) from n=1 to n=16 equals 243880 seconds which is 2.8 days

    def perform(partnered_signup_id)
      begin
        ::PartneredSignupService::DeliverWebhook.new(partnered_signup_id:).run # raises ArgumentError on failure
      rescue
        raise WebhookFailed
      end
    end

  end
end
