# frozen_string_literal: true

class StripeMissedWebhooksJob < ApplicationJob
  queue_as :default
  def perform
    events = StripeService::Event.list({ limit: 100, created: { gte: Time.now.to_i - 5 * 60 }, delivery_success: false }).data
    if events.any?
      if events.count == 100
        Airbrake.notify("🚨 100+ Stripe webhooks failed in the past five minutes.")
      else
        Airbrake.notify("🚨 #{events.count} Stripe webhooks failed in the past five minutes.")
      end
    end
  end

end
