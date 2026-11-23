# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Application project info page", type: :system do
  let(:user) { create(:user) }

  before do
    # The apply layout loads intlTelInput from a CDN, which the url_whitelist blocks.
    driven_by :cuprite, screen_size: [1400, 1400], options: {
      timeout: 15,
      process_timeout: 60,
      js_errors: false,
      url_whitelist: [/\Ahttp:\/\/127\.0\.0\.1:\d+\//],
    }

    session = create(:user_session, user:, expiration_at: 1.day.from_now, verified: true)
    allow_any_instance_of(ApplicationController).to receive(:find_current_session).and_return(session)
  end

  def description_field
    find_field("event_application_description")
  end

  context "for an adult-run project" do
    let(:application) do
      create(:event_application, user:, teen_led: false, description: "Too short", committed_amount_cents: 500_00)
    end

    before { visit project_info_application_path(application) }

    it "counts the description's words up to the 50 it needs" do
      expect(page).to have_text("48 more words required")
      expect(description_field.evaluate_script("this.validationMessage")).to eq("Please enter at least 50 words")

      description_field.fill_in(with: Faker::Lorem.words(number: 49).join(" "))
      expect(page).to have_text("1 more word required")

      description_field.fill_in(with: Faker::Lorem.words(number: 50).join(" "))
      expect(page).to have_no_text("more word")
      expect(description_field.evaluate_script("this.validationMessage")).to eq("")
    end

    it "asks for the funding source only while the committed amount is above zero" do
      expect(find_field("committed_amount_field").value).to eq("500.00")
      expect(page).to have_css("#event_application_funding_source[required]")

      fill_in "committed_amount_field", with: "0"
      expect(page).to have_css("#event_application_funding_source:not([required])", visible: :hidden)

      fill_in "committed_amount_field", with: "12.50"
      expect(page).to have_css("#event_application_funding_source[required]")
    end
  end

  context "for a teen-led project" do
    let(:application) { create(:event_application, user:, teen_led: true, description: "Our robotics team", website_url: "https://hackclub.com") }

    before { visit project_info_application_path(application) }

    it "doesn't count the description's words" do
      expect(page).to have_no_text("more word")
      expect(description_field.evaluate_script("this.validationMessage")).to eq("")
    end

    it "requires the website only while the applicant says they have one, and empties it when they don't" do
      expect(page).to have_css("#website_url_field[required]")

      select "No", from: "event_application_has_website"
      expect(page).to have_css("#website_url_field:not([required])", visible: :hidden)
      expect(find("#website_url_field", visible: :hidden).value).to eq("")

      select "Yes", from: "event_application_has_website"
      expect(page).to have_css("#website_url_field[required]")
    end
  end
end
