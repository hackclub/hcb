# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ledger/items/_decline_reason" do
  # `CardCharge#stripe_card` is `optional: true`, so this partial can't assume a
  # card is there — rendering one without it used to raise
  # `undefined method 'initially_activated?' for nil`.
  context "when the card charge has no StripeCard" do
    # Creating the raw transaction links a CardCharge to it; the Stripe card id
    # on the authorization has no local StripeCard, so it's left unset.
    let(:card_charge) { create(:raw_pending_stripe_transaction).reload.card_charge }
    let(:ledger_item) { create(:ledger_item, linked_object: card_charge) }

    it "renders without raising" do
      expect(card_charge.stripe_card).to be_nil

      expect do
        render partial: "ledger/items/decline_reason", locals: {
          ledger_item:,
          include_troubleshooting: true,
          include_external: true
        }
      end.not_to raise_error

      expect(rendered).to include("hcb@hackclub.com")
    end
  end
end
