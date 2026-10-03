# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Transaction popovers", type: :system do
  include SystemSessionSupport

  let(:user) { create(:user, phone_number: "+18556254225") }
  let(:event) { create(:event, :with_positive_balance) }
  let(:hcb_code) { event.canonical_transactions.sole.local_hcb_code }
  let(:popover) { "#shared_popover" }

  def open_popover
    click_on "TEST DONATION"
    expect(page).to have_css("#{popover} #shared_popover_title", text: "for $1,000.00")
    # Wait for the slide-in to finish so clicks land where the close button ends up
    expect(page).to have_css(popover, style: { transform: "matrix(1, 0, 0, 1, 0, 0)" })
  end

  before do
    create(:organizer_position_invite, :accepted, event:, user:)
    Flipper.enable(:hcb_code_popovers_2023_06_16, user)

    sign_in(user)
    visit event_transactions_path(event)
    click_on "No thanks, bring me straight to HCB"
  end

  it "loads the transaction into the popover and shows its URL" do
    open_popover

    expect(page).to have_css("#{popover} turbo-frame##{hcb_code.public_id}[complete]")
    expect(page).to have_current_path(hcb_code_path(hcb_code))
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
    expect(page).to have_current_path(hcb_code_path(hcb_code))
  end
end
