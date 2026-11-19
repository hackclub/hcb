# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Transaction popovers", type: :system do
  let(:user) { create(:user, phone_number: "+18556254225") }
  let(:event) { create(:event, :with_positive_balance) }
  let(:hcb_code) { event.canonical_transactions.sole.local_hcb_code }
  let(:popover) { "#shared_popover" }

  def press_escape = page.driver.browser.keyboard.type(:escape)
  def expect_closed(selector) = expect(page).to have_no_css("#{selector}[open]", visible: :all)
  def transitions = evaluate_script("document.querySelector('#shared_popover').getAnimations().map(a => a.transitionProperty)")
  def open_modals = evaluate_script("[...document.querySelectorAll('dialog:modal')].map(dialog => dialog.id)")

  def open_popover
    click_on "TEST DONATION"
    expect(page).to have_css("#{popover} #shared_popover_title", text: "for $1,000.00")
    # Wait for the slide-in to finish so clicks land where the close button ends up
    expect(page).to have_css(popover, style: { translate: "none", opacity: "1" })
  end

  before do
    create(:organizer_position_invite, :accepted, event:, user:)

    sign_in(user)
    visit event_transactions_path(event)
    click_on "No thanks, bring me straight to HCB"
  end

  it "loads the transaction into the popover and shows its URL" do
    open_popover

    expect(page).to have_css("#{popover} turbo-frame##{hcb_code.public_id}[complete]")
    expect(page).to have_current_path(event_transactions_path(event, popover: hcb_code_path(hcb_code)))
  end

  it "restores the ledger URL and title when closed" do
    ledger_title = page.title
    open_popover

    find("#{popover} .modal__close").click

    expect_closed(popover)
    expect(page).to have_current_path(event_transactions_path(event))
    expect(page).to have_title(ledger_title)
  end

  it "slides in, and out with the transaction still showing" do
    click_on "TEST DONATION"
    expect(transitions).to include("translate")
    expect(page).to have_css(popover, style: { translate: "none", opacity: "1" })

    find("#{popover} .modal__close").click

    expect(page).to have_css("#{popover}[data-closing] turbo-frame##{hcb_code.public_id}")
    expect(transitions).to include("translate")
    expect_closed(popover)
    expect(page).to have_no_css("#{popover} turbo-frame", visible: :all)
  end

  it "closes on browser back" do
    open_popover

    go_back

    expect_closed(popover)
    expect(page).to have_current_path(event_transactions_path(event))
  end

  it "reopens on browser back after being closed" do
    open_popover
    find("#{popover} .modal__close").click
    expect_closed(popover)

    go_back

    expect(page).to have_css(popover)
    expect(page).to have_current_path(event_transactions_path(event, popover: hcb_code_path(hcb_code)))
  end

  context "with a tag" do
    let!(:tag) { Tag.create!(event:, label: "Snacks", emoji: "🍕", color: "green") }

    # The menu would be inert on <body>, behind the popover, and so would the confirmation
    it "deletes it through the menu and confirmation inside the popover" do
      open_popover
      within(popover) { click_on "+ Add tag" }

      find("button[title='Delete this tag']").click
      click_on "Confirm"

      expect(page).to have_no_css(".swal-overlay--show-modal")
      expect { tag.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "opens the create tag modal from its menu on top of the popover" do
      open_popover
      within(popover) { click_on "+ Add tag" }
      click_on "Create tag"

      expect(page).to have_css("#create_tag[open]")
      fill_in "Tag name", with: "Travel"
      expect(open_modals).to contain_exactly("shared_popover", "create_tag")

      press_escape
      expect_closed("#create_tag")
      expect(open_modals).to eq(["shared_popover"])
    end
  end

  # Morphing drops `open`, which alone would leave it hidden but blocking the page
  it "reopens with fresh content after a morph refresh, as a reload would" do
    open_popover
    execute_script("document.querySelector('#{popover} turbo-frame').dataset.stale = true")

    execute_script("Turbo.session.refresh(location.href)")

    # The refresh reloads the page and its frames before the popover's own
    expect(page).to have_css("#{popover} turbo-frame##{hcb_code.public_id}[complete]:not([data-stale])", wait: 10)
    expect(open_modals).to eq(["shared_popover"])
    expect(page).to have_current_path(event_transactions_path(event, popover: hcb_code_path(hcb_code)))
  end

  it "ignores a ?popover= that matches no link, however it's written" do
    visit event_transactions_path(event, popover: %q{"]) , [x='})

    expect(page).to have_css("h1", text: "Transactions")
    expect_closed(popover)
  end
end
