# frozen_string_literal: true

class StripeMissedWebhooksJob < ApplicationJob
  queue_as :default
  sidekiq_options retry: false

  def perform
    # events missed that are at least one minute old but not more than 6 minutes old
    # we don't report events less than a minute old as they could still be delivering
    events = StripeService::Event.list({ limit: 100, created: { gte: Time.now.to_i - 6 * 60, lte: Time.now.to_i - 60 }, delivery_success: false }).data
    if events.any?
      if events.count == 100
        Rails.error.unexpected "🚨 100+ Stripe webhooks failed in the past five minutes."
      else
        Rails.error.unexpected "🚨 #{events.count} Stripe webhooks failed in the past five minutes: #{events.pluck(:id).to_sentence}."
      end
    end
  end

end
