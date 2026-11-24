# frozen_string_literal: true

require "rails_helper"

# Escape closes whatever's on top, one press at a time (app/javascript/layers.js)
RSpec.describe "Escape", type: :system do
  let(:user) { create(:user, phone_number: "+18556254225") }

  def press_escape = page.driver.browser.keyboard.type(:escape)

  before { sign_in(user) }

  it "closes a menu in the mobile sidebar before the sidebar" do
    page.driver.resize(390, 844)
    visit my_reimbursements_path
    toggle = find("[aria-label='Open navigation']")
    toggle.click
    find(".user-menu-trigger", match: :first).click
    expect(page).to have_link("Sign out")

    press_escape
    expect(page).to have_no_link("Sign out")
    expect(toggle["aria-expanded"]).to eq("true")

    press_escape
    expect(page).to have_css("[aria-label='Open navigation'][aria-expanded=false]")
  end
end
