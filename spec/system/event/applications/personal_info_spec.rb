# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Application personal info", type: :system do
  let(:user) { create(:user, full_name: "Fiona Hackworth") }
  let(:country_field) { "event_application_address_country" }
  let(:restriction_notice) { "This is because of regulatory restrictions" }

  before do
    # The page loads intl-tel-input from a CDN, which the system spec driver
    # blocks; stand in for it so phone_input.js doesn't throw on load.
    page.driver.browser.evaluate_on_new_document(<<~JS)
      window.intlTelInput = () => ({ getNumber: () => "" })
    JS

    sign_in(user)
  end

  def sign_in(user)
    user_session = create(:user_session, user:, expiration_at: 1.day.from_now, verified: true)

    jar = ActionDispatch::Request.new(Rails.application.env_config).cookie_jar
    jar.encrypted[:session_token] = user_session.session_token

    visit auth_users_path
    page.driver.set_cookie("session_token", jar[:session_token])
  end

  def country_validation_message
    page.evaluate_script("document.getElementById('#{country_field}').validationMessage")
  end

  it "warns about and rejects a disallowed country until another is picked" do
    application = create(:event_application, user:)
    visit personal_info_application_path(application)

    expect(page).to have_select(country_field)
    expect(page).to have_no_text(restriction_notice)

    select "India", from: country_field
    expect(page).to have_text("HCB is not supported in India. #{restriction_notice}")
    expect(country_validation_message).to eq("HCB is not supported in this country")

    select "Canada", from: country_field
    expect(page).to have_no_text(restriction_notice)
    expect(country_validation_message).to be_empty
  end

  it "shows the warning on load for a saved disallowed country" do
    application = create(:event_application, user:, address_country: "RU")
    visit personal_info_application_path(application)

    expect(page).to have_text("HCB is not supported in Russia")
    expect(country_validation_message).to eq("HCB is not supported in this country")
  end

  it "still requires a country after clearing the selection" do
    application = create(:event_application, user:, address_country: "CA")
    visit personal_info_application_path(application)

    select "Select a country", from: country_field

    expect(page.evaluate_script("document.getElementById('#{country_field}').validity.valueMissing")).to be(true)
  end
end
