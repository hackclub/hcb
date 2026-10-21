# frozen_string_literal: true

require "rails_helper"

RSpec.describe HcbCodesController, type: :controller do
  include SessionSupport
  include_context "card locking charges"
  render_views

  let(:stripe_card) { create(:stripe_card, :with_stripe_id, stripe_cardholder: create(:stripe_cardholder, user:), event:) }

  let!(:charges) do
    [61, 31, 1].map do |days|
      create_settled_card_charge(user:, stripe_card:, settled_at: days.days.ago, amount_cents: -20_00, merchant_network_id: "vercel-1", merchant_name: "VERCEL INC")
    end
  end

  before { Subscription::Detect.new(stripe_card:).run }

  it "shows admins that the charge was detected as a subscription, with links to the other charges" do
    create_session(create(:user, :make_auditor), verified: true)

    get :show, params: { id: charges.last.hashid }

    expect(response.body).to include("Detected as a subscription")
    charges.first(2).each { |hcb_code| expect(response.body).to include(hcb_code_path(hcb_code)) }
  end

  it "doesn't show it to the event's members" do
    create(:organizer_position, user:, event:)
    create_session(user, verified: true)
    # The merchant modal shown to members reads the currency.
    raw_stripe_transaction = charges.last.raw_stripe_transaction
    raw_stripe_transaction.update!(stripe_transaction: raw_stripe_transaction.stripe_transaction.merge("merchant_currency" => "usd"))

    get :show, params: { id: charges.last.hashid }

    expect(response).to be_successful
    expect(response.body).not_to include("Detected as a subscription")
  end
end
