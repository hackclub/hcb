# frozen_string_literal: true

class StripeMissedWebhooksJob < ApplicationJob
  queue_as :default
  sidekiq_options retry: false

  def perform
    events = StripeService::Event.list({ limit: 100, created: { gte: Time.now.to_i - 5 * 60 }, delivery_success: false }).data
    if events.any?
      if events.count == 100
        Rails.error.unexpected "🚨 100+ Stripe webhooks failed in the past five minutes."
      else
        Rails.error.unexpected "🚨 #{events.count} Stripe webhooks failed in the past five minutes: #{events.pluck(:id).to_sentence}."
      end
    end
  end

end
