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
  let(:popover_url) { ledger_item_path(charge.local_hcb_code.ledger_item) }
  let(:decline_id) { "declined_information_#{charge.local_hcb_code.ledger_item.hashid}" }
  let(:decline_modal) { "##{decline_id}" }

  # Sends Escape to the focused element without clicking anything first
  def press_escape = page.driver.browser.keyboard.type(:escape)
  def click_backdrop = page.driver.browser.mouse.click(x: 5, y: 5)
  def open_modals = evaluate_script("[...document.querySelectorAll('dialog.modal[open]')].map(dialog => dialog.id)")
  # Not just faded out, but closed
  def expect_closed(selector) = expect(page).to have_no_css("#{selector}[open]", visible: :all)
  # The modal on top at a point, whether its box or its backdrop is there
  def covering(x, y) = evaluate_script("(el => (el.matches('.modal-backdrop') ? el.nextElementSibling : el.closest('dialog'))?.id)(document.elementFromPoint(#{x}, #{y}))")

  # Clicks the popover's right edge, which is clear of any modal centered on top of it
  def over_popover
    rect = evaluate_script("document.querySelector('#{popover}').getBoundingClientRect().toJSON()")
    [rect["right"] - 10, rect["top"] + (rect["height"] / 2)]
  end

  def click_over_popover
    x, y = over_popover
    page.driver.browser.mouse.click(x:, y:)
  end

  def open_popover
    find("[data-popover-state-url='#{popover_url}']", match: :first).click
    expect(page).to have_css("#{popover} turbo-frame[complete]", text: "Card not activated")
    # Wait for the slide-in to finish so clicks land where elements end up
    expect(page).to have_css(popover, style: { translate: "none" })
  end

  def open_decline_details
    within(popover) { find("[data-modal]", text: "Card not activated").click }
    # Settled, so clicks land where it stays
    expect(page).to have_css("#{decline_modal}[open]", text: "Activate your new card", style: { scale: "none" })
    # Stacked on the popover, whose backdrop stays put, and covering it
    expect(open_modals).to contain_exactly("shared_popover", decline_id)
    expect(covering(*over_popover)).to eq(decline_id)
  end

  before do
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

    expect_closed(decline_modal)
    expect(page).to have_css(popover, text: "Card not activated")
    expect(covering(*over_popover)).to eq("shared_popover")
    expect(page).to have_current_path(stripe_card_path(card, popover: popover_url))
    # The backdrop still dims the page behind the popover
    dark = evaluate_script("document.documentElement.dataset.dark") == "true"
    expect(evaluate_script("getComputedStyle(document.querySelector('#{popover}').previousElementSibling).backgroundColor")).to eq(dark ? "rgba(0, 0, 0, 0.5)" : "rgba(0, 0, 0, 0.3)")
  end

  it "closes only the topmost modal on Escape or a backdrop click" do
    open_decline_details
    press_escape

    expect_closed(decline_modal)
    expect(page).to have_css(popover)
    expect(page).to have_current_path(stripe_card_path(card, popover: popover_url))

    open_decline_details
    click_backdrop

    expect_closed(decline_modal)
    expect(page).to have_css(popover)
    expect(page).to have_current_path(stripe_card_path(card, popover: popover_url))

    open_decline_details
    click_over_popover

    expect_closed(decline_modal)
    expect(page).to have_css(popover)
    expect(page).to have_current_path(stripe_card_path(card, popover: popover_url))

    click_backdrop

    expect_closed(popover)
    expect(page).to have_current_path(stripe_card_path(card))
  end

  # The browser lets a page animate one Escape per click, so its own Escape
  # handling would close the popover at once on the second press
  it "animates each out on Escape, one press at a time" do
    open_decline_details

    press_escape
    expect(page).to have_css("#{decline_modal}[open][data-closing]")
    expect_closed(decline_modal)

    press_escape
    expect(page).to have_css("#{popover}[open][data-closing]")
    expect_closed(popover)
  end

  it "closes the popover along with the modal on top of it on browser back" do
    open_decline_details

    go_back

    expect_closed(decline_modal)
    expect_closed(popover)
    expect(page).to have_current_path(stripe_card_path(card))
  end

  it "leaves no modals open after following a link out of a modal on the popover" do
    open_decline_details

    within(decline_modal) { click_on "Activate your new card" }

    expect_closed(popover)
    expect(open_modals).to be_empty

    open_popover
    open_decline_details
  end

  it "keeps a modal on the popover working after another frame in the popover renders" do
    open_decline_details
    within(decline_modal) { find(".modal__close").click }
    expect_closed(decline_modal)

    within(popover) { find("[aria-label=Rename]").click }
    expect(page).to have_field("ledger_item[memo]")

    open_decline_details
  end

  it "replaces a modal on the popover with the fresh copy when the popover reloads" do
    open_decline_details
    within(decline_modal) { find(".modal__close").click }
    expect_closed(decline_modal)

    within(popover) do
      fill_in "comment[content]", with: "Why was this declined?"
      click_on "Add comment"
      expect(page).to have_text("Why was this declined?")
    end

    open_decline_details
    expect(page).to have_css(decline_modal, count: 1, visible: :all)
  end

  context "as an auditor" do
    let(:user) { create(:user, :make_auditor, phone_number: "+18556254225") }

    it "opens a ledger item's decline details on top of its popover" do
      open_decline_details

      within(decline_modal) { find(".modal__close").click }

      expect_closed(decline_modal)
      expect(page).to have_css(popover, text: "Card not activated")
    end
  end
end
