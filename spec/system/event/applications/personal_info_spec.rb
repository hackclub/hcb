# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Application personal info", type: :system do
  let(:user) { create(:user, full_name: "Fiona Hackworth") }
  let(:country_field) { "event_application_address_country" }
  let(:restriction_notice) { "This is because of regulatory restrictions" }

  before do
    stub_intl_tel_input
    sign_in(user)
  end

  def country_validity(property)
    page.evaluate_script("document.getElementById('#{country_field}').#{property}")
  end

  it "warns about and rejects a disallowed country until another is picked" do
    application = create(:event_application, user:)
    visit personal_info_application_path(application)

    expect(page).to have_select(country_field)
    expect(page).to have_no_text(restriction_notice)

    select "India", from: country_field
    expect(page).to have_text("HCB is not supported in India. #{restriction_notice}")
    expect(country_validity("validationMessage")).to eq("HCB is not supported in this country")

    select "Canada", from: country_field
    expect(page).to have_no_text(restriction_notice)
    expect(country_validity("validationMessage")).to be_empty
  end

  it "shows the warning on load for a saved disallowed country" do
    application = create(:event_application, user:, address_country: "RU")
    visit personal_info_application_path(application)

    expect(page).to have_text("HCB is not supported in Russia")
    expect(country_validity("validationMessage")).to eq("HCB is not supported in this country")
  end

  it "still requires a country after clearing the selection" do
    application = create(:event_application, user:, address_country: "CA")
    visit personal_info_application_path(application)

    select "Select a country", from: country_field

    expect(country_validity("validity.valueMissing")).to be(true)
  end
end
