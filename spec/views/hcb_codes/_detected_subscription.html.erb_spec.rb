# frozen_string_literal: true

require "rails_helper"

RSpec.describe "hcb_codes/_detected_subscription" do
  include_context "card locking charges"

  before { travel_to(Time.zone.local(2026, 11, 1, 12)) }

  let(:user) { create(:user, full_name: "Ada Lovelace") }
  let(:viewer) { create(:user, :make_auditor) }
  let(:stripe_card) { create(:stripe_card, :with_stripe_id, stripe_cardholder: create(:stripe_cardholder, user:), event:) }
  let(:ledger_items) do
    [0, 30, 60].map do |day|
      create_settled_card_charge(user:, stripe_card:, settled_at: 70.days.ago + day.days, amount_cents: -20_00, merchant_network_id: "vercel-1").ledger_item
    end
  end
  let(:subscription) do
    ledger_items.each { |ledger_item| Subscription::Detect.new(ledger_item).run }
    Subscription.sole
  end

  def render_partial
    current_user = viewer
    view.define_singleton_method(:current_user) { current_user }
    assign(:hcb_code, ledger_items.last.hcb_code)
    render partial: "hcb_codes/detected_subscription", locals: { subscription: }
  end

  it "says what is charged and when the next charge is due" do
    render_partial

    expect(rendered.squish).to include("charges $20.00 monthly").and include("Next charge expected around")
  end

  it "says when the next charge is overdue" do
    subscription
    travel_to(Time.zone.local(2026, 12, 1, 12))

    render_partial

    expect(rendered).to include("Overdue: expected around")
  end

  it "says when the subscription has lapsed" do
    subscription
    travel_to(Time.zone.local(2027, 1, 5, 12))

    render_partial

    expect(rendered.squish).to include("charged $20.00 monthly").and include("Lapsed: no charge since")
  end

  it "shows how the confidence adds up" do
    render_partial

    expect(rendered).to include("Confidence #{subscription.confidence} out of 100").and include("charges 10/25")
  end

  it "shows whose card each charge was on" do
    render_partial

    expect(rendered.scan("Ada Lovelace").size).to eq(3)
  end

  it "is hidden from people who aren't admins" do
    viewer.update!(access_level: :user)

    render_partial

    expect(rendered).to be_blank
  end
end
