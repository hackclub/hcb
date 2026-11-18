# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Modals in transaction popovers", type: :system do
  let(:user) { create(:user, phone_number: "+18556254225") }
  let(:event) { create(:event) }
  let(:card) { create(:stripe_card, :with_stripe_id, event:, stripe_cardholder: create(:stripe_cardholder, user:)) }
  let(:popover) { "#shared_popover" }
  let!(:charge) do
    raw = create(:raw_pending_stripe_transaction, stripe_card: card, stripe_merchant_category_code: "5462")
    raw.stripe_transaction["request_history"] = [{ "reason" => "card_inactive" }]
    raw.save!

    create(:canonical_pending_transaction, event:, amount_cents: -1000, raw_pending_stripe_transaction: raw).tap(&:decline!)
  end
  let(:popover_url) { hcb_code_path(charge.local_hcb_code) }
  let(:decline_modal) { "#declined_information_#{charge.local_hcb_code.hashid}" }
  let(:new_ledger) { false }

  # Sends Escape to the focused element without clicking anything first
  def press_escape = page.driver.browser.keyboard.type(:escape)
  def click_backdrop = page.driver.browser.mouse.click(x: 5, y: 5)

  def open_popover
    find("[data-popover-state-url='#{popover_url}']", match: :first).click
    expect(page).to have_css("#{popover} turbo-frame[complete]", text: "Card not activated")
    # Wait for the slide-in to finish so clicks land where elements end up
    expect(page).to have_css(popover, style: { transform: "matrix(1, 0, 0, 1, 0, 0)" })
  end

  def open_decline_details
    within(popover) { find("[data-modal]", text: "Card not activated").click }
    expect(page).to have_css(decline_modal, text: "Activate your new card")
  end

  before do
    Flipper.enable(:new_ledger_everywhere_2026_07_13) if new_ledger
    create(:organizer_position, event:, user:)
    sign_in(user)
    visit stripe_card_path(card)
    open_popover
  end

  it "opens a transaction's decline details on top of its popover and returns to the popover when closed" do
    open_decline_details

    expect(page).to have_css(popover)
    expect(page).to have_current_path(stripe_card_path(card, popover: popover_url))

    within(decline_modal) { find(".modal__close").click }

    expect(page).to have_no_css(decline_modal)
    expect(page).to have_css(popover, text: "Card not activated")
    expect(page).to have_current_path(stripe_card_path(card, popover: popover_url))
    # The backdrop still dims the page behind the popover
    expect(page).to have_css(".blocker", style: { "background-color": "rgba(0, 0, 0, 0.3)" })
  end

  it "closes only the topmost modal on Escape or a backdrop click" do
    open_decline_details
    press_escape

    expect(page).to have_no_css(decline_modal)
    expect(page).to have_css(popover)
    expect(page).to have_current_path(stripe_card_path(card, popover: popover_url))

    open_decline_details
    click_backdrop

    expect(page).to have_no_css(decline_modal)
    expect(page).to have_css(popover)
    expect(page).to have_current_path(stripe_card_path(card, popover: popover_url))

    click_backdrop

    expect(page).to have_no_css(popover)
    expect(page).to have_current_path(stripe_card_path(card))
  end

  it "closes the popover along with the modal on top of it on browser back" do
    open_decline_details

    go_back

    expect(page).to have_no_css(decline_modal)
    expect(page).to have_no_css(popover)
    expect(page).to have_current_path(stripe_card_path(card))
  end

  it "leaves no modals open after following a link out of a modal on the popover" do
    open_decline_details

    within(decline_modal) { click_on "Activate your new card" }

    expect(page).to have_no_css(popover)
    expect(evaluate_script("$.modal.isActive()")).to be(false)

    open_popover
    open_decline_details
  end

  it "keeps a modal on the popover working after another frame in the popover renders" do
    open_decline_details
    within(decline_modal) { find(".modal__close").click }

    within(popover) { find("[aria-label=Rename]").click }
    expect(page).to have_field("hcb_code[memo]")

    open_decline_details
  end

  it "replaces a modal on the popover with the fresh copy when the popover reloads" do
    open_decline_details
    within(decline_modal) { find(".modal__close").click }

    within(popover) do
      fill_in "comment[content]", with: "Why was this declined?"
      click_on "Add comment"
      expect(page).to have_text("Why was this declined?")
    end

    open_decline_details
    expect(page).to have_css(decline_modal, count: 1, visible: :all)
  end

  context "with the new ledger" do
    let(:user) { create(:user, :make_auditor, phone_number: "+18556254225") }
    let(:popover_url) { ledger_item_path(charge.local_hcb_code.ledger_item) }
    let(:decline_modal) { "#declined_information_#{charge.local_hcb_code.ledger_item.hashid}" }
    let(:new_ledger) { true }

    it "opens a ledger item's decline details on top of its popover" do
      open_decline_details

      within(decline_modal) { find(".modal__close").click }

      expect(page).to have_no_css(decline_modal)
      expect(page).to have_css(popover, text: "Card not activated")
    end
  end
end
