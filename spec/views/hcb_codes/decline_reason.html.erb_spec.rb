# frozen_string_literal: true

require "rails_helper"

RSpec.describe "hcb_codes/_decline_reason" do
  def render_partial(hcb_code)
    render partial: "hcb_codes/decline_reason", locals: {
      hcb_code:,
      include_troubleshooting: true,
      include_external: true
    }
  end

  # `decline!` is called on plenty of transactions that never touched a Stripe
  # card — canceled ACH transfers, rejected checks, canceled disbursements — so
  # this partial has to survive `hcb_code.stripe_card` being nil.
  context "when the declined transaction isn't a card charge" do
    let(:event) do
      create(:event).tap { |event| create(:canonical_pending_transaction, amount_cents: 1000, event:, fronted: true) }
    end
    let(:ach_transfer) { create(:ach_transfer, event:) }
    let(:hcb_code) { ach_transfer.local_hcb_code }

    before do
      create(:canonical_pending_transaction, hcb_code: hcb_code.hcb_code).decline!
    end

    it "renders without raising" do
      expect { render_partial(hcb_code) }.not_to raise_error
      expect(rendered).to include("Transaction declined").or include("Troubleshooting")
    end
  end

  # A card charge whose StripeCard row is missing locally (the Stripe card id on
  # the authorization doesn't resolve) hits the same nil.
  context "when the card charge has no local StripeCard record" do
    let(:hcb_code) { create(:hcb_code, code_type: ::TransactionGroupingEngine::Calculate::HcbCode::STRIPE_CARD_CODE) }

    before do
      raw = create(:raw_pending_stripe_transaction)
      raw.stripe_transaction["request_history"] = [{ "reason" => "card_inactive" }]
      raw.save!

      cpt = create(:canonical_pending_transaction, hcb_code: hcb_code.hcb_code, raw_pending_stripe_transaction: raw)
      cpt.decline!
    end

    it "renders without raising" do
      expect(hcb_code.stripe_card).to be_nil
      expect { render_partial(hcb_code) }.not_to raise_error
      expect(rendered).to include("hcb@hackclub.com")
    end
  end
end
