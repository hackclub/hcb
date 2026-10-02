# frozen_string_literal: true

require "rails_helper"

# The login code page imports FingerprintJS from a CDN, which the URL allowlist blocks
RSpec.describe "Email login", type: :system, allow_js_errors: true do
  let(:user) { create(:user, phone_number: "+18556254225") }

  def request_login_code
    visit auth_users_path
    fill_in "email", with: user.email
    click_on "Continue"
    expect(page).to have_text("We just sent a login code to #{user.email}")
  end

  def emailed_login_code
    ActionMailer::Base.deliveries.last.html_part.body.to_s[/\d{3}-\d{3}/]
  end

  it "signs in with the emailed login code" do
    request_login_code

    fill_in "login_code", with: emailed_login_code
    click_on "Continue", match: :first

    expect(page).to have_current_path(root_path)
    expect(user.user_sessions.count).to eq(1)
  end

  it "rejects a wrong login code without creating a session" do
    request_login_code

    fill_in "login_code", with: emailed_login_code.tr("0-9", "1-90")
    click_on "Continue", match: :first

    expect(page).to have_text("Invalid login code")
    expect(page).to have_field("login_code")
    expect(user.user_sessions).to be_empty
  end

  it "sends the user back to the start once the login expires" do
    request_login_code
    code = emailed_login_code

    travel 16.minutes
    fill_in "login_code", with: code
    click_on "Continue", match: :first

    expect(page).to have_text("Please start again.")
    expect(page).to have_current_path(auth_users_path)
    expect(user.user_sessions).to be_empty
  end

  it "rejects a login code that was issued to a different user" do
    other_user = create(:user)
    other_code = other_user.login_codes.create!.pretty
    request_login_code

    fill_in "login_code", with: other_code
    click_on "Continue", match: :first

    expect(page).to have_text("Invalid login code")
    expect(User::Session.count).to eq(0)
  end
end
