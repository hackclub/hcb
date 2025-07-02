# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProcessLoginService do
  def setup_context
    user = create(:user)
    login = create(:login, user:)
    service = described_class.new(login:)

    { user:, login:, service: }
  end

  describe "#process_webauthn" do
    it "errors on invalid json" do
      setup_context => { service: }

      ok = service.process_webauthn(
        raw_credential: "INVALID",
        challenge: "INVALID"
      )

      expect(ok).to be(false)
      expect(service.errors.messages).to eq({ base: ["Invalid security key"] })
    end

    it "errors if we can't find a matching credential in the db"
    it "errors if we can't validate the provided credential"
    it "succeeds when the provided credential is valid"
  end

  describe "#process_totp" do
    it "errors if the user doesn't have totp configured" do
      setup_context => { service:, login: }

      ok = service.process_totp(code: "123-456")

      expect(ok).to be(false)
      expect(service.errors.messages).to eq({ base: ["Invalid one-time password"] })
      expect(login.reload.authenticated_with_totp).to be_nil
    end

    it "errors if the code is invalid" do
      freeze_time do
        setup_context => { service:, user:, login: }
        totp = user.create_totp!
        code = ROTP::TOTP.new(totp.secret, issuer: User::Totp::ISSUER).at(Time.now)

        travel(1.hour) # the code should now be expired

        ok = service.process_totp(code:)

        expect(ok).to be(false)
        expect(service.errors.messages).to eq({ base: ["Invalid one-time password"] })
        expect(login.reload.authenticated_with_totp).to be_nil
      end
    end

    it "succeeds when the code is valid" do
      freeze_time do
        setup_context => { service:, user:, login: }
        totp = user.create_totp!
        code = ROTP::TOTP.new(totp.secret, issuer: User::Totp::ISSUER).at(Time.now)

        ok = service.process_totp(code:)

        expect(ok).to be(true)
        expect(totp.reload.last_used_at).to eq(Time.zone.now)
        expect(login.reload.authenticated_with_totp).to eq(true)
        expect(service.errors).to be_empty
      end
    end
  end

  describe "#process_login_code" do
    context "sms" do
      def stub_twilio(user:, success: true)
        verification_service = instance_double(TwilioVerificationService)
        expect(verification_service).to(
          receive(:check_verification_token)
            .with(user.phone_number, "123456")
            .and_return(success)
        )
        expect(TwilioVerificationService).to receive(:new).and_return(verification_service)
      end

      it "errors on invalid codes" do
        setup_context => { service:, user:, login: }
        stub_twilio(user:, success: false)

        ok = service.process_login_code(code: "123-456", sms: true)

        expect(ok).to be(false)
        expect(service.errors.messages).to eq({ base: ["Invalid login code"] })
        expect(login.reload.authenticated_with_sms).to be_nil
      end

      it "succeeds when the provided code is valid" do
        setup_context => { service:, user:, login: }
        stub_twilio(user:, success: true)

        ok = service.process_login_code(code: "123-456", sms: true)

        expect(ok).to be(true)
        expect(service.errors).to be_empty
        expect(login.reload.authenticated_with_sms).to eq(true)
      end
    end

    context "email" do
      it "errors on invalid codes" do
        setup_context => { service:, user:, login: }

        ok = service.process_login_code(code: "123-456", sms: false)

        expect(ok).to be(false)
        expect(login.reload.authenticated_with_email).to be_nil
        expect(service.errors.messages).to eq({ base: ["Invalid login code"] })
      end

      it "succeeds when the provided code is valid" do
        setup_context => { service:, user:, login: }
        login_code = create(:login_code, user:)

        ok = service.process_login_code(code: login_code.code, sms: false)

        expect(ok).to be(true)
        expect(login.reload.authenticated_with_email).to eq(true)
        expect(service.errors).to be_empty
      end
    end
  end
end
