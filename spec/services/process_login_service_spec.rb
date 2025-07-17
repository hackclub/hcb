# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProcessLoginService do
  include WebAuthnSupport

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

    it "errors if we can't find a matching credential in the db" do
      setup_context => { service:, login:, user: }
      webauthn_credential = create_webauthn_credential(user:)

      # Remove the record from the DB (but it still exists in the client)
      webauthn_credential.destroy!

      webauthn_challenge = generate_webauthn_challenge(user:)
      credential = get_webauthn_credential(challenge: webauthn_challenge)

      ok = service.process_webauthn(
        raw_credential: JSON.dump(credential),
        challenge: webauthn_challenge
      )

      expect(ok).to be(false)
      expect(service.errors.messages).to eq({ base: ["Invalid security key"] })
      expect(login.reload.authenticated_with_webauthn).to be_nil
    end

    it "errors if we can't validate the provided credential" do
      setup_context => { service:, user: }
      create_webauthn_credential(user:)

      webauthn_challenge = generate_webauthn_challenge(user:)
      credential = get_webauthn_credential(challenge: webauthn_challenge)

      # Use the credential a first time
      expect(
        service.process_webauthn(
          raw_credential: JSON.dump(credential),
          challenge: webauthn_challenge
        )
      ).to eq(true)

      # Set up a second login
      login = create(:login, user:)
      service = described_class.new(login:)

      # Attempt to use the same credential again
      ok = service.process_webauthn(
        raw_credential: JSON.dump(credential),
        challenge: webauthn_challenge
      )

      expect(ok).to be(false)
      expect(service.errors.messages).to eq({ base: ["Failed to verify security key"] })
      expect(login.reload.authenticated_with_webauthn).to be_nil
    end

    it "succeeds when the provided credential is valid" do
      setup_context => { service:, login:, user: }
      webauthn_credential = create_webauthn_credential(user:)
      initial_sign_count = webauthn_credential.sign_count

      webauthn_challenge = generate_webauthn_challenge(user:)
      credential = get_webauthn_credential(challenge: webauthn_challenge)

      ok = service.process_webauthn(
        raw_credential: JSON.dump(credential),
        challenge: webauthn_challenge
      )

      expect(ok).to be(true)
      expect(service.errors.messages).to be_empty
      expect(login.reload.authenticated_with_webauthn).to eq(true)
      expect(webauthn_credential.reload.sign_count).to eq(initial_sign_count + 1)
    end
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

  describe "#process_backup_code" do
    it "errors if the code is invalid" do
      setup_context => { service:, login: }

      ok = service.process_backup_code(code: "abc123")

      expect(ok).to be(false)
      expect(login.reload.authenticated_with_backup_code).to be_nil
      expect(service.errors.messages).to eq({ base: ["Invalid backup code, please try again."] })
    end

    it "errors if the code has already been used" do
      setup_context => { service:, user:, login: }

      backup_code = user.generate_backup_codes!.first
      user.activate_backup_codes!
      expect(user.redeem_backup_code!(backup_code)).to be(true)

      ok = service.process_backup_code(code: backup_code)
      expect(ok).to be(false)
      expect(login.reload.authenticated_with_backup_code).to be_nil
      expect(service.errors.messages).to eq({ base: ["Invalid backup code, please try again."] })
    end

    it "succeeds when the provided code is valid" do
      setup_context => { service:, user:, login: }

      backup_code = user.generate_backup_codes!.first
      user.activate_backup_codes!

      ok = service.process_backup_code(code: backup_code)

      expect(ok).to be(true)
      expect(login.reload.authenticated_with_backup_code).to eq(true)
      expect(service.errors).to be_empty

      expect(user.backup_codes.active.count).to eq(9)
      used = user.backup_codes.used.sole
      expect(used.authenticate_code(backup_code)).to be_truthy
    end
  end
end
