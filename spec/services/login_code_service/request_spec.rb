# frozen_string_literal: true

require "rails_helper"

describe LoginCodeService::Request do
  include TwilioSupport

  let(:ip_address) { "127.0.0.1" }
  let(:user_agent) { "fake firefox" }

  context "when a user with a given email does not exist" do
    it "creates that user with login code and emails" do
      new_email = "test@example.com"
      expect(User.find_by(email: new_email)).to be_nil

      expect(LoginCodeMailer).to receive_message_chain(:send_code, :deliver_now)
      response = nil
      expect do
        response = described_class.new(email: new_email,
                                       ip_address:,
                                       user_agent:).run
      end.to change { User.count }.by(1)

      user = User.find_by(email: new_email)
      expect(user.login_codes.count).to eq(1)
      login_code = user.login_codes.first
      expect(login_code.ip_address).to eq(ip_address)
      expect(login_code.user_agent).to eq(user_agent)

      expect(response).to eq({
                               id: user.id,
                               email: user.email,
                               status: "login code sent",
                               method: :email,
                               login_code:
                             })
    end
  end


  context "when a user with a given email does exist" do
    it "creates that user with login code and emails" do
      user = create(:user)

      expect(LoginCodeMailer).to receive_message_chain(:send_code, :deliver_now)
      response = nil
      expect do
        response = described_class.new(email: user.email,
                                       ip_address:,
                                       user_agent:).run
      end.to change { User.count }.by(0)

      expect(user.login_codes.count).to eq(1)
      login_code = user.login_codes.first
      expect(login_code.ip_address).to eq(ip_address)
      expect(login_code.user_agent).to eq(user_agent)

      expect(response).to eq({
                               id: user.id,
                               email: user.email,
                               status: "login code sent",
                               method: :email,
                               login_code:
                             })
    end
  end

  context "when SMS is requested" do
    let(:user) { create(:user, phone_number: "+18005550100") }

    it "sends the SMS while under the daily cap" do
      stub_twilio_sms_verification(phone_number: user.phone_number)
      allow(Rails.cache).to receive(:increment).and_return(1)

      response = described_class.new(email: user.email, sms: true, ip_address:, user_agent:).run

      expect(TwilioVerificationService.new).to have_received(:send_verification_request).with(user.phone_number)
      expect(response[:method]).to eq(:sms)
    end

    # The Turnstile gate covers the zero-factor login form, but not the paths
    # that reach this service with a factor already cleared (or from sudo-mode
    # reauthentication) — the cap is the backstop for those.
    it "falls back to email once the daily cap is spent" do
      allow(Rails.cache).to receive(:increment).and_return(LoginCodeService::Request::DAILY_SMS_LIMIT + 1)
      allow(Rails.error).to receive(:report)
      expect(TwilioVerificationService).not_to receive(:new)
      expect(LoginCodeMailer).to receive_message_chain(:send_code, :deliver_now)

      response = described_class.new(email: user.email, sms: true, ip_address:, user_agent:).run

      expect(response[:method]).to eq(:email)
      expect(Rails.error).to have_received(:report).with(an_instance_of(Errors::TwilioAbuseError))
    end
  end

  context "errors" do
    context "when user has an error" do
      it "does not save the user, does not create a login code and returns an error" do
        invalid_email = "bad@bad"
        expect(LoginCodeMailer).not_to receive(:send_code)

        response = nil
        expect do
          response = described_class.new(email: invalid_email,
                                         ip_address:,
                                         user_agent:).run
        end.to change { User.count }.by(0)

        expect(LoginCode.count).to eq(0)
        expect(response[:error].attribute_names).to eq([:email])
      end
    end
  end
end
