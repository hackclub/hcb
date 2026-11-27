# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Donation page", type: :request do
  let(:event) { create(:event) }

  before do
    allow(TurnstileService).to receive_messages(site_key: "0x0000site", secret_key: "0x0000secret")
  end

  it "posts the monthly form to the recurring donations create route" do
    get start_donation_donations_path(event.slug, monthly: true)

    expect(response).to have_http_status(:ok)
    form = response.parsed_body.css("form").find { |f| f.at_css("input[name='recurring_donation[name]']") }
    expect(form).to be_present
    expect(form["method"]).to eq("post")
    expect(form["action"]).to eq("/#{event.slug}/recurring")
  end
end
