# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Menus", type: :system do
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

  it "closes again when clicked twice before it's positioned" do
    # Both clicks land before floating-ui's position promise resolves
    execute_script("const t = document.querySelector('.user-menu-trigger'); t.click(); t.click()")

    expect(page).to have_no_link("Sign out")
    expect(toggle["aria-expanded"]).to eq("false")
    expect(page).to have_no_css("body > .menu__content", visible: :all)
  end

  it "hands focus back to its button when closed with Escape from inside" do
    toggle.click
    # Focus a link inside, as Tab would
    execute_script("[...document.querySelectorAll('a')].find(a => a.textContent.includes('Sign out') && a.checkVisibility()).focus()")
    expect(evaluate_script("document.activeElement.textContent")).to include("Sign out")
    press_escape

    expect(page).to have_no_link("Sign out")
    expect(evaluate_script("document.activeElement === document.querySelector('.user-menu-trigger')")).to be(true)
  end

  it "signs out through its Turbo DELETE link" do
    toggle.click
    click_on "Sign out"

    expect(page).to have_current_path(auth_users_path, ignore_query: true)
    expect(user.user_sessions.not_expired).to be_empty
  end
end
