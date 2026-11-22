# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Card popovers", type: :system do
  let(:user) { create(:user, phone_number: "+18556254225") }
  let(:event) { create(:event) }
  let(:card) { create(:stripe_card, :with_stripe_id, event:, stripe_cardholder: create(:stripe_cardholder, user:)) }
  let(:charge) do
    raw_pending_stripe_transaction = create(:raw_pending_stripe_transaction, stripe_card: card, amount_cents: -1234, stripe_merchant_category_code: "5462")
    create(:canonical_pending_transaction, raw_pending_stripe_transaction:, amount_cents: -1234, event:)
  end
  let(:hcb_code) { charge.local_hcb_code }
  let(:popover) { "#shared_popover" }
  let(:card_frame) { "#{popover} turbo-frame#stripe_card_#{card.public_id}" }

  before do
    create(:organizer_position_invite, :accepted, event:, user:)
    charge

    sign_in(user)
    visit event_cards_overview_path(event)
    click_on "No thanks, bring me straight to HCB"
    # The overlay fades out over a second and intercepts clicks until it is gone
    expect(page).to have_no_css(".welcome")
  end

  shared_examples "a card popover" do
    it "swaps a transaction into the open popover and returns to the card on back" do
      find("[data-popover-frame-id='stripe_card_#{card.public_id}']").click
      expect(page).to have_css("#{card_frame}[complete]")
      expect(page).to have_current_path(event_cards_overview_path(event, popover: stripe_card_path(card)))

      # Clicking a transaction used to close and reopen the popover, and the
      # close handler emptied the body it had just been filled with
      find("#{popover} [data-popover-frame-id='#{hcb_code.public_id}']").click

      expect(page).to have_css("#{popover} turbo-frame##{hcb_code.public_id}[complete]")
      expect(page).to have_no_css(card_frame)
      expect(page).to have_current_path(event_cards_overview_path(event, popover: hcb_code_path(hcb_code)))

      go_back

      expect(page).to have_css("#{card_frame}[complete]")
      expect(page).to have_no_css("#{popover} turbo-frame##{hcb_code.public_id}")
      expect(page).to have_current_path(event_cards_overview_path(event, popover: stripe_card_path(card)))
    end
  end

  context "with the new ledger" do
    before { Flipper.enable(:new_ledger_everywhere_2026_07_13, user) }

    include_examples "a card popover"
  end

  context "with the legacy transaction table" do
    include_examples "a card popover"
  end
end
