# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ACH routing number validation", type: :system do
  include SystemSessionSupport

  let(:user) { create(:user, phone_number: "+18556254225") }
  let(:event) { create(:event, organizers: [user]) }
  let(:invalid_routing_number) { "[data-controller=external-validation].field_with_errors" }

  def stub_institution(routing_number, **institution)
    stub_request(:get, "https://api.column.com/institutions/#{routing_number}")
      .to_return(status: 200, body: institution.to_json, headers: { "Content-Type" => "application/json" })
  end

  def enter_routing_number(value)
    fill_in "ach_transfer[routing_number]", with: value
  end

  before do
    sign_in(user)
    visit new_event_ach_transfer_path(event)
  end

  it "shows the bank name for a valid routing number" do
    stub_institution("021000021", routing_number_type: "aba", ach_eligible: true, full_name: "JPMORGAN CHASE BANK")

    enter_routing_number("021000021")

    expect(page).to have_text("Jpmorgan Chase Bank")
    expect(page).to have_no_css(invalid_routing_number)
  end

  it "flags a routing number that cannot receive ACH transfers" do
    stub_institution("021000021", routing_number_type: "aba", ach_eligible: false, full_name: "JPMORGAN CHASE BANK")

    enter_routing_number("021000021")

    expect(page).to have_css(invalid_routing_number, text: "This routing number cannot accept ACH transfers.")
  end

  it "rejects a non-numeric routing number without calling Column" do
    enter_routing_number("../../accounts")

    expect(page).to have_css(invalid_routing_number, text: "Bank not found for this routing number.")
    expect(a_request(:get, /api\.column\.com/)).not_to have_been_made
  end
end
