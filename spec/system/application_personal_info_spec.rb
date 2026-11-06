# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Application personal info page", type: :system do
  let(:cosigner_field) { "#event_application_cosigner_email" }

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
    expect(page).to have_css("#{cosigner_field}:not([required])", visible: :hidden)

    select 15.years.ago.year.to_s, from: "event_application_birthday_1i"

    expect(page).to have_css("#{cosigner_field}[required]")
  end

  it "stops requiring a cosigner once a minor changes their birthday to an adult's" do
    visit_personal_info_as(create(:user, birthday: 15.years.ago.to_date))
    expect(page).to have_css("#{cosigner_field}[required]")

    select 25.years.ago.year.to_s, from: "event_application_birthday_1i"

    # Hidden but still required would block the form from submitting
    expect(page).to have_css("#{cosigner_field}:not([required])", visible: :hidden)
  end

  # With a year prompt still selected the date can't be parsed, which must not count as a minor
  it "does not treat a birthday without a year as a minor's" do
    visit_personal_info_as(create(:user, birthday: nil))

    select "January", from: "event_application_birthday_2i"
    select "1", from: "event_application_birthday_3i"
    expect(page).to have_css("#{cosigner_field}:not([required])", visible: :hidden)

    select 15.years.ago.year.to_s, from: "event_application_birthday_1i"
    expect(page).to have_css("#{cosigner_field}[required]")
  end
end
