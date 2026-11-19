# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Transaction popovers", type: :system do
  let(:user) { create(:user, phone_number: "+18556254225") }
  let(:event) { create(:event, :with_positive_balance) }
  let(:hcb_code) { event.canonical_transactions.sole.local_hcb_code }
  let(:popover) { "#shared_popover" }

  def press_escape = page.driver.browser.keyboard.type(:escape)
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

    expect(page).to have_no_css(popover)
    expect(page).to have_current_path(event_transactions_path(event))
    expect(page).to have_title(ledger_title)
  end

  it "closes on browser back" do
    open_popover

    go_back

    expect(page).to have_no_css(popover)
    expect(page).to have_current_path(event_transactions_path(event))
  end

  it "reopens on browser back after being closed" do
    open_popover
    find("#{popover} .modal__close").click
    expect(page).to have_no_css(popover)

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
      expect(page).to have_no_css("#create_tag")
      expect(open_modals).to eq(["shared_popover"])
    end
  end

  it "closes cleanly when a morph refresh drops its open attribute" do
    open_popover

    execute_script("Turbo.session.refresh(location.href)")

    expect(page).to have_no_css(popover)
    expect(open_modals).to be_empty
  end

  it "ignores a ?popover= that matches no link, however it's written" do
    visit event_transactions_path(event, popover: %q{"]) , [x='})

    expect(page).to have_css("h1", text: "Transactions")
    expect(page).to have_no_css(popover)
  end
end
