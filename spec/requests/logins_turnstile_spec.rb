# frozen_string_literal: true

require "rails_helper"

# `POST /logins/:id/sms` spends a Twilio Verify message and needs no session to
# reach, so it's gated on a solved Turnstile challenge.
RSpec.describe "LoginsController Turnstile protection", type: :request do
  include TurnstileSupport
  include TwilioSupport

  let(:user) do
    create(:user, phone_number: "+18005550100").tap do |u|
      # Can't be set through the factory: `User#on_phone_number_update` clears
      # verification whenever the number changes, creation included.
      u.update!(phone_number_verified: true)
    end
  end
  let(:login) { create(:login, user:) }
  let(:token) { "0.turnstile-token" }

  before do
    enable_turnstile!
    stub_twilio_sms_verification(phone_number: user.phone_number)
  end

  def request_sms_code(params = {})
    post "/logins/#{login.hashid}/sms", params: { email: user.email }.merge(params)
  end

  it "sends the code when the token verifies" do
    stub_siteverify(success: true)

    request_sms_code("cf-turnstile-response" => token)

    expect(TwilioVerificationService.new).to have_received(:send_verification_request).with(user.phone_number)
  end

  it "sends no SMS and returns the user to the start when the token is missing" do
    request_sms_code

    expect(TwilioVerificationService.new).not_to have_received(:send_verification_request)
    expect(response).to redirect_to(auth_users_path)
    expect(flash[:error]).to eq(TurnstileProtection::FAILURE_MESSAGE)
  end

  it "sends no SMS when Cloudflare rejects the token" do
    stub_siteverify(success: false)

    request_sms_code("cf-turnstile-response" => token)

    expect(TwilioVerificationService.new).not_to have_received(:send_verification_request)
    expect(response).to redirect_to(auth_users_path)
  end

  # The widget stamps the hostname it was solved on, so a token minted against
  # our sitekey somewhere else must not be accepted here.
  it "sends no SMS when the token was solved on another hostname" do
    stub_siteverify(success: true, hostname: "evil.example")

    request_sms_code("cf-turnstile-response" => token)

    expect(TwilioVerificationService.new).not_to have_received(:send_verification_request)
  end

  # `#complete` reaches `#sms` through `continue_login` when a login needs a
  # second factor; those requests carry no token by design.
  it "skips the check for a login that has already cleared a factor" do
    # A login stays incomplete after one factor only when a second is required,
    # otherwise `Login`'s `before_save` completes it and `set_login` can no
    # longer find it.
    user.update!(use_sms_auth: true, use_two_factor_authentication: true)
    login.update!(authenticated_with_email: true)

    request_sms_code

    expect(TwilioVerificationService.new).to have_received(:send_verification_request).with(user.phone_number)
  end

  # The forms that 307 into `#sms` are the ones that have to carry a token.
  it "renders the widget on the forms that lead to an SMS code" do
    get auth_users_path
    expect(response.body).to include('data-controller="turnstile"')
    expect(response.body).to include(TurnstileService.site_key)

    get choose_login_preference_login_path(login)
    expect(response.body).to include('data-controller="turnstile"')
  end

  # Once a factor has cleared, the server skips the check (`turnstile_required?`),
  # so don't make people mid-2FA run a challenge whose token nothing reads.
  it "renders no widget once a factor has been cleared" do
    user.update!(use_sms_auth: true, use_two_factor_authentication: true)
    login.update!(authenticated_with_email: true)

    get choose_login_preference_login_path(login)

    expect(response.body).not_to include('data-controller="turnstile"')
  end

  context "when Turnstile isn't configured" do
    before { disable_turnstile! }

    it "sends the code without calling Cloudflare" do
      request_sms_code

      expect(TwilioVerificationService.new).to have_received(:send_verification_request).with(user.phone_number)
      expect(a_request(:post, TurnstileService::Verify::SITEVERIFY_URL)).not_to have_been_made
    end

    it "renders no widget" do
      get auth_users_path

      expect(response.body).not_to include('data-controller="turnstile"')
    end
  end
end
