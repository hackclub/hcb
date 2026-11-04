# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Application project info", type: :system do
  shared_examples "website and political toggles" do
    def required?(id)
      page.evaluate_script("document.getElementById('#{id}').required")
    end

    it "requires the website URL only while the applicant says they have one" do
      visit path

      expect(page).to have_no_field("website_url_field")
      expect(required?("website_url_field")).to be(false)

      select "Yes", from: "event_application_has_website"
      expect(page).to have_field("website_url_field")
      expect(required?("website_url_field")).to be(true)

      fill_in "website_url_field", with: "https://hackclub.com"
      select "No", from: "event_application_has_website"
      expect(page).to have_no_field("website_url_field")
      expect(required?("website_url_field")).to be(false)
      expect(find_field("website_url_field", visible: :all).value).to eq("")
    end

    it "requires the political description only while the applicant says there is one" do
      visit path

      expect(page).to have_no_field("political_description_field")
      expect(required?("political_description_field")).to be(false)

      select "Yes", from: "event_application_has_political"
      expect(page).to have_field("political_description_field")
      expect(required?("political_description_field")).to be(true)

      select "No", from: "event_application_has_political"
      expect(page).to have_no_field("political_description_field")
      expect(required?("political_description_field")).to be(false)
    end

    # The fields' initial visibility is rendered by the server, so make sure it
    # agrees with the selects and that the toggles still work from that state.
    it "shows prefilled answers and hides them again when switched to No" do
      application.update!(website_url: "https://hackclub.com", political_description: "Lobbying")
      visit path

      expect(page).to have_select("event_application_has_website", selected: "Yes")
      expect(page).to have_field("website_url_field", with: "https://hackclub.com")
      expect(page).to have_select("event_application_has_political", selected: "Yes")
      expect(page).to have_field("political_description_field", with: "Lobbying")

      select "No", from: "event_application_has_website"
      select "No", from: "event_application_has_political"
      expect(page).to have_no_field("website_url_field")
      expect(page).to have_no_field("political_description_field")
    end
  end

  let(:application) { create(:event_application, user: create(:user), teen_led: true, description: "A hackathon") }

  before do
    user_session = create(:user_session, user: viewer, verified: true)
    allow_any_instance_of(ApplicationController).to receive(:find_current_session).and_return(user_session)

    # intl-tel-input comes from a CDN, which the driver blocks
    page.driver.browser.evaluate_on_new_document("window.intlTelInput = () => ({ getNumber: () => '' })")
  end

  context "when filling out the application" do
    let(:viewer) { application.user }
    let(:path) { project_info_application_path(application) }

    it_behaves_like "website and political toggles"

    # has_website isn't a model attribute, so the server only learns the
    # applicant has no website from the blanked URL. Autosave fires on the
    # select's `input` event, which comes before the `change` that clears the
    # field; this only works because autosave is debounced.
    it "erases a saved website when the applicant switches to No" do
      application.update!(website_url: "https://hackclub.com")
      visit path

      # Cuprite's `select` only dispatches `change`, which would never trigger
      # autosave, so pick the option the way a browser does: `input`, then
      # `change`.
      page.execute_script(<<~JS)
        const select = document.getElementById("event_application_has_website")
        select.value = "false"
        select.dispatchEvent(new Event("input", { bubbles: true }))
        select.dispatchEvent(new Event("change", { bubbles: true }))
      JS
      expect(page).to have_no_field("website_url_field")
      expect(page).to have_text("Application saved", wait: 5)

      expect(application.reload.website_url).to be_blank
    end
  end

  context "when an admin edits the application" do
    let(:viewer) { create(:user, :make_admin) }
    let(:path) { edit_application_path(application) }

    it_behaves_like "website and political toggles"
  end
end
