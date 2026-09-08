# frozen_string_literal: true

require "rails_helper"

# Saving a donation mints a Stripe PaymentIntent (or, for a monthly one, a
# subscription), which is exactly what card testers want to farm. Both halves
# of the donation form are gated on a solved Turnstile challenge.
RSpec.describe "Donation Turnstile", type: :request do
  include DonationSupport

  let(:event) { create(:event) }
  let(:token) { "0.turnstile-token" }

  before do
    allow(TurnstileService).to receive_messages(site_key: "0x0000site", secret_key: "0x0000secret")
  end

  def stub_siteverify(success:, action: TurnstileService::DONATION_ACTION)
    stub_request(:post, TurnstileService::Verify::SITEVERIFY_URL).to_return(
      status: 200,
      body: { "success" => success, "action" => action, "hostname" => "www.example.com" }.to_json,
      headers: { "Content-Type" => "application/json" }
    )
  end

  it "renders the widget on the donation page" do
    get start_donation_donations_path(event.slug)

    expect(response.body).to include(%(data-turnstile-action-value="#{TurnstileService::DONATION_ACTION}"))
  end

  describe "POST make_donation" do
    def make_donation(params = {})
      post make_donation_donations_path(event.slug), params: {
        donation: { name: "Jane Smith", email: "jane@example.com", amount: "12.34" }
      }.deep_merge(params)
    end

    it "creates the donation when the token verifies" do
      stub_donation_payment_intent_creation
      stub_siteverify(success: true)

      expect { make_donation("cf-turnstile-response" => token) }.to change(Donation, :count).by(1)
    end

    it "refuses without reaching Stripe when the token is missing" do
      expect(StripeService::Customer).not_to receive(:create)

      expect { make_donation }.not_to change(Donation, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(ERB::Util.html_escape(TurnstileProtection::FAILURE_MESSAGE))
    end

    it "refuses when Cloudflare rejects the token" do
      expect(StripeService::Customer).not_to receive(:create)

      stub_siteverify(success: false)

      expect { make_donation("cf-turnstile-response" => token) }.not_to change(Donation, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end

    # A token minted by any other widget on our sitekey carries a different
    # action, so it can't be spent here.
    it "refuses a token solved for a different widget" do
      expect(StripeService::Customer).not_to receive(:create)

      stub_siteverify(success: true, action: TurnstileService::SMS_VERIFICATION_ACTION)

      expect { make_donation("cf-turnstile-response" => token) }.not_to change(Donation, :count)
    end

    # The rejected form comes back filled in, so someone whose token merely
    # expired doesn't have to type everything again.
    it "keeps the submitted details on the re-rendered form" do
      stub_siteverify(success: false)

      make_donation("cf-turnstile-response" => token)

      expect(response.body).to include("Jane Smith", "jane@example.com", "12.34")
    end

    context "when Turnstile isn't configured" do
      before { allow(TurnstileService).to receive_messages(site_key: nil, secret_key: nil) }

      it "creates the donation without calling Cloudflare" do
        stub_donation_payment_intent_creation

        expect { make_donation }.to change(Donation, :count).by(1)
        expect(a_request(:post, TurnstileService::Verify::SITEVERIFY_URL)).not_to have_been_made
      end
    end
  end

  describe "POST create (monthly)" do
    def create_recurring_donation(params = {})
      post event_recurring_donations_path(event.slug), params: {
        recurring_donation: { name: "Jane Smith", email: "jane@example.com", amount: "12.34" }
      }.deep_merge(params)
    end

    it "refuses without reaching Stripe when the token is missing" do
      expect(StripeService::Customer).not_to receive(:create)

      expect { create_recurring_donation }.not_to change(RecurringDonation, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(ERB::Util.html_escape(TurnstileProtection::FAILURE_MESSAGE))
    end
  end
end
