# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Menus", type: :system do
  include SystemSessionSupport

  let(:user) { create(:user, phone_number: "+18556254225") }
  let(:toggle) { find(".user-menu-trigger") }

  # Sends Escape to the focused element without clicking anything first
  def press_escape = page.driver.browser.keyboard.type(:escape)

  before do
    sign_in(user)
    visit my_reimbursements_path
  end

  it "toggles open and closed from its button" do
    toggle.click
    expect(page).to have_link("Sign out")
    expect(toggle["aria-expanded"]).to eq("true")

    toggle.click
    expect(page).to have_no_link("Sign out")
    expect(toggle["aria-expanded"]).to eq("false")
  end

  it "closes on Escape and on an outside click" do
    toggle.click
    press_escape
    expect(page).to have_no_link("Sign out")

    toggle.click
    find("h1", text: "Reimbursements").click
    expect(page).to have_no_link("Sign out")
  end

  it "signs out through its Turbo DELETE link" do
    toggle.click
    click_on "Sign out"

    expect(page).to have_current_path(auth_users_path, ignore_query: true)
    expect(user.user_sessions.not_expired).to be_empty
  end
end
