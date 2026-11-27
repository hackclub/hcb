# frozen_string_literal: true

require "rails_helper"

RSpec.describe EventsController, "termination requests in the danger zone" do
  include SessionSupport
  render_views

  let(:event) { create(:event) }
  let(:signee) { create(:user) }
  let(:manager) { create(:user) }

  before do
    create(:organizer_position, user: signee, event:, role: :manager, is_signee: true)
    create(:organizer_position, user: manager, event:, role: :manager)
  end

  def danger_zone
    get :edit, params: { id: event.slug, tab: "details" }
    expect(response).to have_http_status(:ok)
    response.parsed_body.at_css("#request_termination")&.parent || response.parsed_body
  end

  it "offers a contract signee the request form" do
    create_session(signee, verified: true)

    page = danger_zone
    expect(page.css("a[data-modal='request_termination']").text).to eq("Request termination")
    expect(page.at_css("form[action='#{event_termination_requests_path(event)}'] textarea[name='event_termination_request[reason]']")).to be_present
  end

  it "tells a manager who has not signed the contract to ask a signee" do
    create_session(manager, verified: true)

    page = danger_zone
    expect(page.css("a[data-modal='request_termination']")).to be_empty
    expect(page.text).to include("Only a contract signee can request termination")
  end

  it "shows the pending request with a withdraw button to a signee" do
    create(:event_termination_request, event:, requested_by: signee, reason: "The hackathon is over.")
    create_session(signee, verified: true)

    page = danger_zone
    expect(page.text).to include("requested termination on")
    expect(page.text).to include("The hackathon is over.")
    withdraw_form = page.at_css("form[action$='/withdraw']")
    expect(withdraw_form.text).to include("Withdraw request")
  end

  it "shows the pending request without a withdraw button to a non-signee" do
    create(:event_termination_request, event:, requested_by: signee)
    create_session(manager, verified: true)

    page = danger_zone
    expect(page.text).to include("requested termination on")
    expect(page.css("form[action$='/withdraw']")).to be_empty
  end

  it "hides the section for demo-mode organizations" do
    event.update!(demo_mode: true)
    create_session(signee, verified: true)

    page = danger_zone
    expect(page.text).not_to include("Terminate this organization")
  end
end
