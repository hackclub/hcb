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
  let(:item) { charge.local_hcb_code.ledger_item }
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

  it "swaps a transaction into the open popover and returns to the card on back" do
    find("[data-popover-frame-id='stripe_card_#{card.public_id}']").click
    expect(page).to have_css("#{card_frame}[complete]")
    expect(page).to have_current_path(event_cards_overview_path(event, popover: stripe_card_path(card)))

    # Clicking a transaction used to close and reopen the popover, and the
    # close handler emptied the body it had just been filled with.
    #
    # Dispatched from script rather than with the mouse: hovering the row
    # reveals its "Add tag" button, and in the narrow card popover that can
    # squeeze the memo link to nothing, so a mouse click lands on the button.
    find("#{popover} [data-popover-frame-id='#{item.public_id}']").execute_script("this.click()")

    expect(page).to have_css("#{popover} turbo-frame##{item.public_id}[complete]")
    expect(page).to have_no_css(card_frame)
    expect(page).to have_current_path(event_cards_overview_path(event, popover: ledger_item_path(item)))

    go_back

    expect(page).to have_css("#{card_frame}[complete]")
    expect(page).to have_no_css("#{popover} turbo-frame##{item.public_id}")
    expect(page).to have_current_path(event_cards_overview_path(event, popover: stripe_card_path(card)))
  end
end
