# frozen_string_literal: true

class StripeMissedWebhooksJob < ApplicationJob
  queue_as :default
  sidekiq_options retry: false

  def perform
    # events missed that are at least one minute old but not more than 6 minutes old
    # we don't report events less than a minute old as they could still be delivering
    events = StripeService::Event.list({ limit: 100, created: { gte: Time.now.to_i - 6 * 60, lte: Time.now.to_i - 60 }, delivery_success: false }).data
    return if events.empty?

    page_full = events.count == 100
    events_by_type = events.group_by(&:type)

    message = ["🚨 #{page_full ? "100+" : events.count} Stripe #{"webhook".pluralize(events.count)} failed in the past five minutes."]
    if events_by_type.key?("issuing_authorization.request")
      message << "Stripe doesn't retry issuing_authorization.request, so it approved or declined those card authorizations without HCB's response."
    end
    message << if page_full
                 "Of the 100 most recent: #{events_by_type.map { |type, events_of_type| "#{events_of_type.count} #{type}" }.join(", ")}."
               else
                 events_by_type.map { |type, events_of_type| "#{type}: #{events_of_type.pluck(:id).join(", ")}." }.join(" ")
               end

    Rails.error.unexpected message.join(" ")
  end

end
