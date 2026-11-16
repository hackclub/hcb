# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Ledger filters", type: :system do
  # An admin, so no organizer position puts the welcome tour over the page
  let(:user) { create(:user, :make_admin, phone_number: "+18556254225") }
  let(:event) { create(:event) }

  before do
    Flipper.enable_actor(:new_ledger_2026_07_17, user)
    sign_in(user)
  end

  # Ledger::Item#refresh! recomputes these columns from transactions these items don't have.
  def ledger_item(memo, **columns)
    item = create(:ledger_item, custom_memo: memo, datetime: Time.current)
    Ledger::Mapping.create!(ledger: event.ledger, ledger_item: item, on_primary_ledger: true)
    item.update_columns(ct_count: 1, **columns)
  end

  def open_filter(tab, ledger = page)
    ledger.find("button[aria-label='Add filter']").click
    click_on tab
  end

  it "adds a date range to the filters already applied, keeping the last day" do
    ledger_item("Last day expense", amount_cents: -100, datetime: Time.utc(2024, 1, 31, 23))
    ledger_item("Next month expense", amount_cents: -100, datetime: Time.utc(2024, 2, 1))
    ledger_item("Last day revenue", amount_cents: 100, datetime: Time.utc(2024, 1, 31))
    visit event_ledger_path(event, query: { amount_cents: { "$lt" => 0 } }.to_json)

    open_filter "Date"
    find("[data-ledger-query-target='start']").set(Date.new(2024, 1, 1))
    find("[data-ledger-query-target='end']").set(Date.new(2024, 1, 31))
    click_on "Filter transactions"

    expect(page).to have_text("Between 01/01/2024 and 01/31/2024")
    expect(page).to have_text("Expenses")
    expect(page).to have_text("Last day expense")
    expect(page).to have_no_text("Next month expense")
    expect(page).to have_no_text("Last day revenue")
  end

  # 19.99 * 100 is 1998.9999999999998 in floating point, which the chip couldn't read back.
  it "converts an amount to whole cents, so its chip reads it back" do
    ledger_item("Exactly the minimum", amount_cents: -1999)
    ledger_item("A cent under", amount_cents: -1998)
    visit event_ledger_path(event)

    open_filter "Amount"
    find("[data-ledger-query-target='minimum']").set("19.99")
    click_on "Filter transactions"

    expect(page).to have_text("More than $19.99")
    expect(page).to have_text("Exactly the minimum")
    expect(page).to have_no_text("A cent under")
  end

  it "keeps the filters and search already applied when picking a merchant" do
    allow_any_instance_of(Event).to receive(:merchants).and_return([{ id: "1234", name: "Corner Store" }])
    visit event_ledger_path(event, query: { amount_cents: { "$lt" => 0 } }.to_json, q: "coffee")

    open_filter "Merchant"
    click_on "Corner Store"

    within(".filter-menu__chips") do
      expect(page).to have_text("Corner Store")
      expect(page).to have_text("Expenses")
    end
    expect(page).to have_field(with: "coffee")
  end

  context "on the card grants page" do
    let(:event) { create(:event, plan_type: Event::Plan::HackClubAffiliate) }

    before do
      allow_any_instance_of(CardGrant).to receive(:transfer_money)
      create(:card_grant, event:, purpose: "Travel")
      Flipper.enable_actor(:new_ledger_everywhere_2026_07_13, user)
    end

    # Each step waits for the frame to update before checking the page never left.
    it "filters the card grant ledger without leaving the page" do
      overview = event_card_grant_overview_path(event)
      visit overview
      ledger = find("turbo-frame#card_grant_transaction_overview")

      open_filter "Receipts", ledger
      click_on "Missing receipts"
      expect(ledger).to have_css(".filter-menu__chips", text: "Missing receipts")
      expect(page).to have_current_path(overview)

      open_filter "Amount", ledger
      find("[data-ledger-query-target='minimum']").set("5")
      click_on "Filter transactions"
      expect(ledger).to have_css(".filter-menu__chips", text: "More than $5.00")
      expect(ledger).to have_css(".filter-menu__chips", text: "Missing receipts")
      expect(page).to have_current_path(overview)

      ledger.find("a[aria-label='Clear filters']").click
      expect(ledger).to have_no_css(".filter-menu__chips")
      expect(page).to have_current_path(overview)
    end
  end

  it "drops a range whose fields are cleared, leaving the other filters alone" do
    ledger_item("Old expense", amount_cents: -100, datetime: Time.utc(2023, 6, 1))
    ledger_item("Old revenue", amount_cents: 100, datetime: Time.utc(2023, 6, 1))
    visit event_ledger_path(event, query: { amount_cents: { "$lt" => 0 }, datetime: { "$gte" => "2024-01-01" } }.to_json)
    expect(page).to have_no_text("Old expense")

    open_filter "Date"
    find("[data-ledger-query-target='start']").set("")
    click_on "Filter transactions"

    expect(page).to have_no_text("After 01/01/2024")
    expect(page).to have_text("Old expense")
    expect(page).to have_no_text("Old revenue")
  end
end
