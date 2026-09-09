# frozen_string_literal: true

require "rails_helper"

# Signed-in donors shouldn't have to retype an email we already know. The
# public donation page is skipped by `signed_in_user`, so this is the only
# place that identity gets applied.
RSpec.describe "Donation form prefill", type: :request do
  let(:event) { create(:event) }
  let(:user) { create(:user, full_name: "Jane Smith", email: "jane@example.com") }

  before do
    allow(TurnstileService).to receive_messages(site_key: "0x0000site", secret_key: "0x0000secret")
  end

  def email_field(body, model: "donation")
    Nokogiri::HTML5(body).at_css(%(input[name="#{model}[email]"]))
  end

  def name_field(body, model: "donation")
    Nokogiri::HTML5(body).at_css(%(input[name="#{model}[name]"]))
  end

  def sign_in_user(user)
    user_session = create(:user_session, user:, verified: true)
    allow_any_instance_of(SessionsHelper)
      .to receive(:find_current_session)
      .and_return(user_session)
  end

  it "leaves the form blank for signed-out visitors" do
    get start_donation_donations_path(event.slug)

    expect(response).to have_http_status(:ok)
    expect(email_field(response.body)[:value]).to be_blank
    expect(name_field(response.body)[:value]).to be_blank
  end

  it "prefills name and email when signed in" do
    sign_in_user(user)

    get start_donation_donations_path(event.slug)

    expect(response).to have_http_status(:ok)
    expect(email_field(response.body)[:value]).to eq(user.email)
    expect(name_field(response.body)[:value]).to eq(user.name)
  end

  it "does not prefill for organizers" do
    create(:organizer_position, event:, user:)
    sign_in_user(user)

    get start_donation_donations_path(event.slug)

    expect(email_field(response.body)[:value]).to be_blank
    expect(name_field(response.body)[:value]).to be_blank
  end

  it "prefills the monthly donation form" do
    sign_in_user(user)

    get start_donation_donations_path(event.slug, monthly: true)

    expect(response).to have_http_status(:ok)
    expect(email_field(response.body, model: "recurring_donation")[:value]).to eq(user.email)
    expect(name_field(response.body, model: "recurring_donation")[:value]).to eq(user.name)
  end

  it "lets query params override the signed-in account" do
    sign_in_user(user)

    get start_donation_donations_path(event.slug, name: "Pat Donor", email: "pat@example.com")

    expect(email_field(response.body)[:value]).to eq("pat@example.com")
    expect(name_field(response.body)[:value]).to eq("Pat Donor")
  end
end
