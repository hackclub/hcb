# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin tools pinned cards", type: :system do
  let(:user) { create(:user, :make_auditor) }

  let(:pinned_section) { find("[data-admin-tools-pinned-cards-target=pinnedSection]", visible: :all) }
  let(:pinned_grid) { "[data-admin-tools-pinned-cards-target=pinnedGrid]" }

  before do
    allow_any_instance_of(ApplicationController).to receive(:find_current_session)
      .and_return(create(:user_session, user:, expiration_at: 1.day.from_now, verified: true))
    # The async badges would otherwise call Airtable and other external services
    allow_any_instance_of(AdminController).to receive(:pending_task).and_return(0)
  end

  def pin_icon(card_id)
    find("##{card_id} [data-admin-tools-pinned-cards-target=pin]", visible: :all)
  end

  def pinned_card_ids
    all("#{pinned_grid} > div", visible: :all).map { |card| card[:id] }
  end

  it "moves cards into the pinned grid and back to the grid they came from" do
    visit admin_tools_path
    expect(pinned_section).not_to be_visible

    pin_icon("card-ledger").click
    pin_icon("card-users").click

    expect(page).to have_current_path(admin_tools_path) # the click didn't follow the card's link
    expect(pinned_section).to be_visible
    expect(pinned_card_ids).to eq(%w[card-ledger card-users])
    expect(pin_icon("card-ledger")[:color]).to eq("orange")
    expect(page).to have_no_css("#task-grid #card-ledger")

    # Unpinning one of several cards keeps the section open
    pin_icon("card-users").click
    expect(page).to have_css("#info-grid > #card-users")
    expect(pin_icon("card-users")[:color]).to eq("var(--muted)")
    expect(pinned_section).to be_visible

    # Unpinning the last card hides the section once its exit animation ends
    pin_icon("card-ledger").click
    expect(page).to have_css("#task-grid > #card-ledger")
    expect(page).to have_css("[data-admin-tools-pinned-cards-target=pinnedSection]", visible: :hidden)
  end

  it "restores pins saved by the old Alpine implementation" do
    visit admin_tools_path
    # Alpine's $persist stored pins under this key, JSON-encoded. Admins with
    # existing pins should keep them after the switch to Stimulus.
    page.execute_script(<<~JS)
      localStorage.setItem("_x_pinned_cards", JSON.stringify([
        { id: "card-flipper", old_grid_id: "other-grid" },
        { id: "card-pvsa", old_grid_id: "old-card-grid" },
      ]))
    JS
    refresh

    expect(pinned_section).to be_visible
    expect(pinned_card_ids).to eq(%w[card-flipper card-pvsa])
    expect(pin_icon("card-pvsa")[:color]).to eq("orange")

    # A card restored on load still remembers its original grid, even one
    # inside the collapsed "Old cards" section
    pin_icon("card-pvsa").click
    expect(page).to have_css("#old-card-grid > #card-pvsa", visible: :all)

    refresh
    expect(pinned_card_ids).to eq(%w[card-flipper])
  end
end
