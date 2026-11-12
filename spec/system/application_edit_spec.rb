# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin application edit page", type: :system do
  let(:cosigner_field) { "#event_application_cosigner_email" }

  def visit_edit_page_for(application)
    allow_any_instance_of(SessionsHelper)
      .to receive(:find_current_session)
      .and_return(create(:user_session, user: create(:user, :make_admin)))

    # intl-tel-input loads from a CDN that Cuprite blocks
    page.driver.browser.evaluate_on_new_document("window.intlTelInput = () => ({ getNumber: () => '' })")

    visit edit_application_path(application)
  end

  # The field is only rendered for applicants who are already minors, so this
  # page can hide and restore it but never introduce it.
  it "drops the cosigner requirement when a minor's birthday is changed to an adult's, and restores it" do
    applicant = create(:user, birthday: 15.years.ago.to_date)
    visit_edit_page_for(create(:event_application, user: applicant, teen_led: true))
    expect(page).to have_css("#{cosigner_field}[required]")

    select 25.years.ago.year.to_s, from: "event_application_birthday_1i"
    # Hidden but still required would block the form from submitting
    expect(page).to have_css("#{cosigner_field}:not([required])", visible: :hidden)

    select 15.years.ago.year.to_s, from: "event_application_birthday_1i"
    expect(page).to have_css("#{cosigner_field}[required]")
  end
end
