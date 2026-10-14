# frozen_string_literal: true

require "rails_helper"

RSpec.describe HcbCodesController, type: :controller do
  include SessionSupport
  include_context "card locking charges"

  render_views

  let(:organizer) { create(:user) }
  let(:stripe_card) { create(:stripe_card, :with_stripe_id, stripe_cardholder: create(:stripe_cardholder, user:), event:) }
  let!(:first) { create_settled_card_charge(user:, stripe_card:, settled_at: 40.days.ago, merchant_network_id: "spotify-1") }
  let!(:second) { create_settled_card_charge(user:, stripe_card:, settled_at: 10.days.ago, merchant_network_id: "spotify-1") }

  before do
    # Fill in the merchant details the transaction page renders.
    [first, second].each do |hcb_code|
      rst = hcb_code.raw_stripe_transaction
      stripe_transaction = rst.stripe_transaction.merge("merchant_currency" => "usd")
      stripe_transaction["merchant_data"] = stripe_transaction["merchant_data"].merge("city" => "Shelburne", "state" => "VT", "country" => "US", "postal_code" => "05482")
      rst.update!(stripe_transaction:)
    end

    create(:organizer_position, user: organizer, event:)
    create_session(organizer, verified: true)
  end

  it "offers to mark an unlinked card charge as a subscription" do
    get :show, params: { id: second.hashid }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Mark as subscription")
    expect(response.body).to include("mark_as_subscription_#{second.hashid}")
  end

  it "shows a waived charge as part of its subscription" do
    subscription = create(:subscription, stripe_card:, event:, merchant_network_id: "spotify-1", amount_cents: 10_00)
    [first, second].each { |hcb_code| hcb_code.update!(subscription:) }
    subscription.sync_charges!

    get :show, params: { id: second.hashid }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("No receipt needed")
    expect(response.body).to include("View subscription")
    expect(response.body).to include("Not a subscription")
    expect(response.body).not_to include("Mark as subscription")
  end
end
