# frozen_string_literal: true

require "rails_helper"

describe LoginCodeService::Request do
  include TwilioSupport

  let(:ip_address) { "127.0.0.1" }
  let(:user_agent) { "fake firefox" }
  let(:original_cache) { Rails.cache }

  # The test cache is a null_store which silently never increments a counter,
  # so swap in a MemoryStore to exercise the rate-limit guards.
  around do |example|
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    example.run
  ensure
    Rails.cache = original_cache
  end

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

  describe "rate limits" do
    it "blocks email codes once more than 20 are sent in the window" do
      user = create(:user)
      allow(LoginCodeMailer).to receive(:send_code).and_return(double(deliver_now: true))

      20.times { described_class.new(email: user.email, ip_address:, user_agent:).run }

      expect(LoginCodeMailer).not_to receive(:send_code)
      response = described_class.new(email: user.email, ip_address:, user_agent:).run

      expect(response[:error]).to eq("You're requesting too many login codes. Please try again later.")
    end

    it "blocks sms codes once more than 20 are sent in the window" do
      user = create(:user)
      user.update!(phone_number: "+18556254225", use_sms_auth: true, phone_number_verified: true)
      stub_twilio_sms_verification(phone_number: user.phone_number, code: "123456")

      20.times do
        response = described_class.new(email: user.email, sms: true, ip_address:, user_agent:).run
        expect(response[:method]).to eq(:sms)
      end

      response = described_class.new(email: user.email, sms: true, ip_address:, user_agent:).run
      expect(response[:error]).to eq("You're requesting too many SMS codes. Please try again later.")
    end
    it "allows email codes again after the rate limit window expires" do
      user = create(:user)
      allow(LoginCodeMailer).to receive(:send_code).and_return(double(deliver_now: true))

      20.times { described_class.new(email: user.email, ip_address:, user_agent:).run }

      response = described_class.new(email: user.email, ip_address:, user_agent:).run
      expect(response[:error]).to be_present

      travel(1.hour)
      Rails.cache.clear

      allow(LoginCodeMailer).to receive(:send_code).and_return(double(deliver_now: true))
      response = described_class.new(email: user.email, ip_address:, user_agent:).run
      expect(response[:error]).to be_nil
      expect(response[:method]).to eq(:email)
    end

    it "allows sms codes again after the rate limit window expires" do
      user = create(:user)
      user.update!(phone_number: "+18556254225", use_sms_auth: true, phone_number_verified: true)
      stub_twilio_sms_verification(phone_number: user.phone_number, code: "123456")

      20.times do
        described_class.new(email: user.email, sms: true, ip_address:, user_agent:).run
      end

      response = described_class.new(email: user.email, sms: true, ip_address:, user_agent:).run
      expect(response[:error]).to be_present

      travel(1.hour)
      Rails.cache.clear

      stub_twilio_sms_verification(phone_number: user.phone_number, code: "123456")
      response = described_class.new(email: user.email, sms: true, ip_address:, user_agent:).run
      expect(response[:error]).to be_nil
      expect(response[:method]).to eq(:sms)
    end
  end
end
