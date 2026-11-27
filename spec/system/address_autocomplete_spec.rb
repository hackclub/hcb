# frozen_string_literal: true

require "rails_helper"

# The `address-autocomplete` Stimulus controller suggests addresses under the
# street address field as the user types and fills the rest of the address in
# from the one they pick.
RSpec.describe "Address autocomplete", type: :system do
  let(:event) { create(:event) }
  let(:manager) { create(:user) }

  before do
    create(:organizer_position, user: manager, event:, role: :manager, first_time: false)

    allow_any_instance_of(SessionsHelper)
      .to receive(:find_current_session)
      .and_return(create(:user_session, user: manager))
  end

  describe "check form" do
    before do
      stub_address_suggestions(letterman_drive_feature, with: ["1 Lett", { params: hash_including(country: "us") }])
      visit new_event_increase_check_path(event)
    end

    it "fills the address in from a clicked suggestion" do
      fill_in "increase_check_address_line1", with: "1 Lett"

      find("[role=option]", text: "1 Letterman Drive").click

      expect(page).to have_field("increase_check_address_line1", with: "1 Letterman Drive")
      expect(page).to have_field("increase_check_address_city", with: "San Francisco")
      expect(page).to have_select("increase_check_address_state", selected: "California")
      expect(page).to have_field("increase_check_address_zip", with: "94129")
      expect(page).to have_no_css("[role=option]")
    end

    it "picks a suggestion with the keyboard without submitting the form" do
      fill_in "increase_check_address_line1", with: "1 Lett"
      expect(page).to have_css("[role=option]", text: "1 Letterman Drive")

      find_field("increase_check_address_line1").send_keys(:down, :enter)

      expect(page).to have_field("increase_check_address_city", with: "San Francisco")
      expect(page).to have_current_path(new_event_increase_check_path(event))
    end

    it "closes the suggestions on escape and leaves the fields alone" do
      fill_in "increase_check_address_line1", with: "1 Lett"
      expect(page).to have_css("[role=option]", text: "1 Letterman Drive")

      find_field("increase_check_address_line1").send_keys(:escape)

      expect(page).to have_no_css("[role=option]")
      expect(page).to have_field("increase_check_address_line1", with: "1 Lett")
      expect(page).to have_field("increase_check_address_city", with: "")
    end
  end

  describe "wire form" do
    before do
      stub_address_suggestions(oakfield_close_feature, with: ["17 Oak", { params: hash_not_including(:country) }])
      visit new_event_wire_path(event)
    end

    it "searches worldwide until a country is picked and fills the country in from the suggestion" do
      fill_in "wire_address_line1", with: "17 Oak"

      find("[role=option]", text: "17 Oakfield Close").click

      expect(page).to have_field("wire_address_line1", with: "17 Oakfield Close")
      expect(page).to have_field("wire_address_city", with: "Sheffield")
      expect(page).to have_field("wire_address_state", with: "England")
      expect(page).to have_field("wire_address_postal_code", with: "S1 2AB")
      expect(page).to have_select("wire_recipient_country", selected: "United Kingdom")
    end
  end
end
