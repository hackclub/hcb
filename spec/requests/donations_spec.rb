# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Donations", type: :request do
  let(:event) { create(:event) }

  before do
    allow(TurnstileService).to receive_messages(site_key: "0x0000site", secret_key: "0x0000secret")
    stub_request(:post, TurnstileService::Verify::SITEVERIFY_URL).to_return(
      status: 200,
      body: { "success" => true, "action" => TurnstileService::DONATION_ACTION, "hostname" => "www.example.com" }.to_json,
      headers: { "Content-Type" => "application/json" }
    )
  end

  def make_donation(donation)
    post make_donation_donations_path(event.slug), params: {
      "cf-turnstile-response" => "0.turnstile-token",
      donation: { name: "Jane Smith", amount: "12.34" }.merge(donation)
    }
  end

  describe "POST make_donation" do
    it "rejects an email Stripe would refuse before reaching Stripe" do
      expect(StripeService::Customer).not_to receive(:create)

      expect { make_donation(email: '"jane smith"@example.com') }.not_to change(Donation, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("does not appear to be a valid email address")
    end

    it "rejects a missing email instead of crashing" do
      expect(StripeService::Customer).not_to receive(:create)

      expect { make_donation({}) }.not_to change(Donation, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
