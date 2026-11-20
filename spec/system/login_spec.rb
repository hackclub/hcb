# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Login page", type: :system do
  it "opens the logo menu on right click and closes it on an outside click" do
    visit auth_users_path

    find("[data-menu-target=toggle]").right_click
    expect(page).to have_link("Brand guidelines")

    find_field("email").click
    expect(page).to have_no_link("Brand guidelines")
  end

  # The code form used to be rendered straight from the POST that sent the
  # code, leaving the browser on /users/auth. Any full page load after that (a
  # refresh, or Turbo reloading because a deploy changed the assets) dropped
  # the user back on the email form with a code already in their inbox.
  it "keeps the email code form across a reload and signs in with the code" do
    # Named and with a phone number, so signing in goes to the dashboard rather than the profile form
    user = create(:user, full_name: "Orpheus Dino", phone_number: "+18556254225")

    visit auth_users_path
    fill_in "email", with: user.email
    click_on "Continue"

    expect(page).to have_field("login_code")
    login = user.logins.last
    expect(page).to have_current_path(email_login_path(login))

    expect {
      page.refresh
      expect(page).to have_field("login_code")
    }.not_to(change { user.login_codes.count })
    expect(page).to have_current_path(email_login_path(login))

    fill_in "login_code", with: user.login_codes.last.code
    click_on "Continue"

    expect(page).to have_no_field("login_code")
    expect(page).to have_no_current_path(email_login_path(login))
    expect(login.reload).to be_complete
  end
end
