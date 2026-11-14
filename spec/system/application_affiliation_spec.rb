# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Application affiliation form", type: :system do
  let(:user) { create(:user) }
  # Continue submits the project form, so it has to pass browser validation
  # before Turbo gets a chance to ask for confirmation.
  let(:application) do
    create(:event_application, user:,
                               description: Faker::Lorem.words(number: 60).join(" "),
                               planning_duration: "4 months",
                               team_size: 7,
                               annual_budget_cents: 500_00,
                               committed_amount_cents: 0)
  end
  let(:unsaved_warning) { "You have an unsaved affiliation. Are you sure you want to continue?" }

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

    visit project_info_application_path(application)
  end

  # Scoped because each saved affiliation renders a hidden edit form with the
  # same radio labels.
  def pick(type)
    within("form[data-controller=unsaved-affiliation]") { choose type, allow_label_click: true }
  end

  def continue_button
    find_button("Continue →")
  end

  it "warns before continuing with an unsaved affiliation, and stays on the page if cancelled" do
    pick "FIRST Robotics"

    continue_button.click
    within(".swal-modal") do
      expect(page).to have_text(unsaved_warning)
      click_button "Cancel"
    end

    expect(page).to have_no_css(".swal-modal")
    expect(page).to have_current_path(project_info_application_path(application))
    expect(page).to have_field("Team number")
  end

  it "keeps warning when switching between types, and stops once the affiliation is cancelled" do
    pick "FIRST Robotics"
    pick "VEX Robotics"
    expect(continue_button["data-turbo-confirm"]).to eq(unsaved_warning)

    click_button "Cancel"

    expect(page).to have_no_button("Save affiliation")
    expect(continue_button["data-turbo-confirm"]).to be_nil
  end

  it "stops warning once the affiliation is saved, and warns again for a new unsaved one" do
    pick "Hack Club"
    fill_in "Venue name", with: "Pierson Library"
    fill_in "Size", with: "12"
    click_button "Save affiliation"

    expect(page).to have_text("Pierson Library")
    expect(application.affiliations.reload.map(&:name)).to eq(["hack_club"])
    expect(continue_button["data-turbo-confirm"]).to be_nil

    # The saved form is re-rendered inside the turbo frame, so its controller
    # must reconnect and keep guarding the next affiliation.
    pick "FIRST Robotics"
    expect(continue_button["data-turbo-confirm"]).to eq(unsaved_warning)
  end

  it "saves a Destination Imagination affiliation" do
    pick "Destination Imagination"
    select "Early Learning", from: "Level"
    fill_in "Team Number", with: "125-12345"
    fill_in "Size", with: "5"
    click_button "Save affiliation"

    expect(page).to have_text("Early Learning")
    affiliation = application.affiliations.reload.sole
    expect(affiliation.to_s).to eq("Destination Imagination – Early Learning – 125-12345 – 5 people")
  end
end
