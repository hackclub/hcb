# frozen_string_literal: true

require "rails_helper"

RSpec.describe StripeMissedWebhooksJob do
  def stub_failed_events(events)
    allow(StripeService::Event).to receive(:list).and_return(
      Stripe::ListObject.construct_from(
        object: "list",
        data: events.map { |event| event.merge(object: "event") }
      )
    )
  end

  before { allow(Rails.error).to receive(:unexpected) }

  it "only looks at undelivered events created one to six minutes ago" do
    freeze_time
    stub_failed_events([])

    described_class.perform_now

    expect(StripeService::Event).to have_received(:list).with(
      limit: 100,
      delivery_success: false,
      created: { gte: 6.minutes.ago.to_i, lte: 1.minute.ago.to_i }
    )
  end

  it "doesn't report anything when every webhook was delivered" do
    stub_failed_events([])

    described_class.perform_now

    expect(Rails.error).not_to have_received(:unexpected)
  end

  it "reports the failed events grouped by type" do
    stub_failed_events([
                         { id: "evt_1", type: "charge.updated" },
                         { id: "evt_2", type: "issuing_authorization.created" },
                         { id: "evt_3", type: "charge.updated" }
                       ])

    described_class.perform_now

    expect(Rails.error).to have_received(:unexpected).with(
      "🚨 3 Stripe webhooks failed in the past five minutes. charge.updated: evt_1, evt_3. issuing_authorization.created: evt_2."
    )
  end

  it "says Stripe declined an unanswered card authorization" do
    stub_failed_events([
                         { id: "evt_1", type: "issuing_authorization.request" }
                       ])

    described_class.perform_now

    expect(Rails.error).to have_received(:unexpected).with(
      "🚨 1 Stripe webhook failed in the past five minutes. " \
      "Stripe doesn't retry issuing_authorization.request, so it declined those card authorizations. " \
      "issuing_authorization.request: evt_1."
    )
  end

  it "reports counts per type instead of event IDs when the page of failures is full" do
    stub_failed_events(
      Array.new(60) { |i| { id: "evt_auth_#{i}", type: "issuing_authorization.request" } } +
      Array.new(40) { |i| { id: "evt_charge_#{i}", type: "charge.updated" } }
    )

    described_class.perform_now

    expect(Rails.error).to have_received(:unexpected).with(
      "🚨 100+ Stripe webhooks failed in the past five minutes. " \
      "Stripe doesn't retry issuing_authorization.request, so it declined those card authorizations. " \
      "Of the 100 most recent: 60 issuing_authorization.request, 40 charge.updated."
    )
  end
end
