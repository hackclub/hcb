# frozen_string_literal: true

require "rails_helper"

# `POST /users/start_sms_auth_verification` sends a Twilio Verify message to a
# phone number the user just typed in, so it's gated on a solved Turnstile
# challenge.
#
# Controller-spec style so `SessionSupport#create_session` can sign the user in
# (in a request spec it collides with `ActionDispatch::Integration::Runner`).
RSpec.describe UsersController do
  include SessionSupport
  include TurnstileSupport

  let(:user) { create(:user, phone_number: "+18005550100") }
  let(:token) { "0.turnstile-token" }
  let(:enroll_service) { instance_double(UserService::EnrollSmsAuth, start_verification: nil) }

  before do
    enable_turnstile!
    allow(UserService::EnrollSmsAuth).to receive(:new).and_return(enroll_service)
    create_session(user, verified: true)
  end

  # This widget carries its own action, and controller specs run on another
  # host than request specs do.
  def stub_sms_siteverify(success:, action: TurnstileService::SMS_VERIFICATION_ACTION)
    stub_siteverify(success:, action:, hostname: "test.host")
  end

  def start_verification(params = {})
    post(:start_sms_auth_verification, params:, as: :json)
  end

  it "starts the verification when the token verifies" do
    stub_sms_siteverify(success: true)

    start_verification("cf-turnstile-response" => token)

    expect(response).to have_http_status(:ok)
    expect(enroll_service).to have_received(:start_verification)
  end

  it "refuses without reaching Twilio when the token is missing" do
    start_verification

    expect(response).to have_http_status(:forbidden)
    expect(response.parsed_body["error"]).to eq(TurnstileProtection::FAILURE_MESSAGE)
    expect(enroll_service).not_to have_received(:start_verification)
  end

  it "refuses when Cloudflare rejects the token" do
    stub_sms_siteverify(success: false)

    start_verification("cf-turnstile-response" => token)

    expect(response).to have_http_status(:forbidden)
    expect(enroll_service).not_to have_received(:start_verification)
  end

  # A token minted by any other widget on our sitekey carries a different
  # action, so it can't be spent here.
  it "refuses a token solved for a different widget" do
    stub_sms_siteverify(success: true, action: "some-other-widget")

    start_verification("cf-turnstile-response" => token)

    expect(response).to have_http_status(:forbidden)
    expect(enroll_service).not_to have_received(:start_verification)
  end

  context "when Turnstile isn't configured" do
    before { disable_turnstile! }

    it "starts the verification without calling Cloudflare" do
      start_verification

      expect(enroll_service).to have_received(:start_verification)
      expect(a_request(:post, TurnstileService::Verify::SITEVERIFY_URL)).not_to have_been_made
    end
  end
end
