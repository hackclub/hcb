# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Transaction filter menu", type: :system do
  include SystemSessionSupport

  let(:user) { create(:user, phone_number: "+18556254225") }
  let(:event) { create(:event, :with_positive_balance) }

  before do
    create(:canonical_event_mapping, event:, canonical_transaction: create(:canonical_transaction, amount_cents: 1_000, memo: "SMALL COFFEE"))
    create(:organizer_position_invite, :accepted, event:, user:)

    sign_in(user)
    visit event_transactions_path(event)
    click_on "No thanks, bring me straight to HCB"
    find("button[aria-label='Add filter']").click
  end

  it "shows only the selected tab's panel and highlights its button" do
    expect(page).to have_css("button#user.active")
    expect(page).to have_no_button("Filter transactions")

    click_on "Amount"

    expect(page).to have_css("button#amount.active")
    expect(page).to have_no_css("button#user.active")
    expect(page).to have_button("Filter transactions")
  end

  it "filters the ledger by a minimum amount entered in the menu" do
    expect(page).to have_text("SMALL COFFEE")
    click_on "Amount"

    fill_in "minimum_amount", with: "500"
    click_on "Filter transactions"

    expect(page).to have_current_path(/minimum_amount=500\.00/)
    expect(page).to have_text("TEST DONATION")
    expect(page).to have_no_text("SMALL COFFEE")
  end
end
