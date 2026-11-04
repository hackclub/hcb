# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Application personal info page", type: :system do
  def visit_personal_info_as(user)
    allow_any_instance_of(SessionsHelper)
      .to receive(:find_current_session)
      .and_return(create(:user_session, user:))

    # intl-tel-input loads from a CDN that Cuprite blocks
    page.driver.browser.evaluate_on_new_document("window.intlTelInput = () => ({ getNumber: () => '' })")

    visit personal_info_application_path(create(:event_application, user:))
  end

  it "asks for a cosigner once an adult changes their birthday to a minor's" do
    visit_personal_info_as(create(:user, birthday: 25.years.ago.to_date))
    expect(page).to have_no_field("event_application_cosigner_email")

    select 15.years.ago.year.to_s, from: "event_application_birthday_1i"

    expect(page).to have_field("event_application_cosigner_email")
  end

  it "stops asking for a cosigner once a minor changes their birthday to an adult's" do
    visit_personal_info_as(create(:user, birthday: 15.years.ago.to_date))
    expect(page).to have_field("event_application_cosigner_email")

    select 25.years.ago.year.to_s, from: "event_application_birthday_1i"

    expect(page).to have_no_field("event_application_cosigner_email")
  end

  it "does not treat a birthday without a year as a minor's" do
    visit_personal_info_as(create(:user, birthday: nil))

    select "January", from: "event_application_birthday_2i"
    select "1", from: "event_application_birthday_3i"
    expect(page).to have_no_field("event_application_cosigner_email")

    select 15.years.ago.year.to_s, from: "event_application_birthday_1i"
    expect(page).to have_field("event_application_cosigner_email")
  end
end
