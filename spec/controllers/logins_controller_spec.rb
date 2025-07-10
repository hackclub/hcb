# frozen_string_literal: true

require "rails_helper"
require "webauthn/fake_client"

describe LoginsController do
  include SessionSupport
  render_views

  describe "#new" do
    it "shows the current user when logged in" do
      user = create(:user)
      sign_in(user)

      get(:new)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(
        "You’re currently signed into HCB, would you like to head to your dashboard?"
      )
    end

    it "renders a login form when logged out" do
      get(:new)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Sign in to HCB")
    end
  end

  describe "#create" do
    it "creates a user if one doesn't and uses the login code factor" do
      email = "test@example.com"
      expect(User.find_by(email:)).to be_nil

      expect { post(:create, params: { email: "test@example.com" }) }
        .to( change { Login.count }.by(1).and(change { User.count }.by(1)) )

      login = Login.last
      expect(login.user.email).to eq(email)
      expect(response).to redirect_to(login_code_login_path(login))
    end

    it "uses the existing user if the email matches" do
      user = create(:user, email: "test@example.com")

      expect { post(:create, params: { email: user.email }) }
        .to(change { Login.count }.by(1).and(change { User.count }.by(0)))

      login = Login.last
      expect(login.user).to eq(user)
      expect(response).to redirect_to(login_code_login_path(login))
    end
  end

  describe "#login_code" do
    it "sends a code to the user's email and renders the form" do
      user = create(:user, email: "text@example.com")
      login = create(:login, user:)

      expect {
        get(:login_code, params: { id: login.hashid })
      }.to send_email(to: user.email)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Email code")
      expect(response.body).to include("We just sent a login code")
    end

    it "sends an SMS code if the user has opted-in and verified their phone number" do
      user = create(:user, phone_number: "+18556254225")
      # This can't be done through the factory because we have validation logic
      # that clears out `phone_number_verified` when the phone number changes.
      user.update!(use_sms_auth: true, phone_number_verified: true)
      login = create(:login, user:)

      # Stub out the SMS service
      verification_service = instance_double(TwilioVerificationService)
      expect(verification_service).to receive(:send_verification_request).with(user.phone_number)
      expect(TwilioVerificationService).to receive(:new).and_return(verification_service)

      get(:login_code, params: { id: login.hashid })

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("SMS code")
      expect(response.body).to include("We just sent a login code")
    end
  end

  describe "#complete" do
    context "webauthn" do
      it "signs the user in and redirects" do
        user = create(:user, webauthn_id: WebAuthn.generate_user_id, phone_number: "+18556254225")
        login = create(:login, user:)
        webauthn_client = WebAuthn::FakeClient.new(WebAuthn.configuration.origin)

        # Simulate `WebauthnCredentialsController#register_options`
        create_options = WebAuthn::Credential.options_for_create(
          user: {
            id: user.webauthn_id,
            name: user.email,
            display_name: user.name
          },
          authenticator_selection: {
            authenticator_attachment: "platform",
            user_verification: "discouraged"
          }
        )

        # Create a new credential (this logic is performed in the browser)
        # See `app/javascript/controllers/webauthn_register_controller.js`
        create_payload = webauthn_client.create(challenge: create_options.challenge)

        # Simulate `WebauthnCredentialsController#create`
        credential = WebAuthn::Credential.from_create(create_payload)
        expect(credential.verify(create_options.challenge)).to eq(true)

        webauthn_credential = user.webauthn_credentials.create!(
          webauthn_id: credential.id,
          public_key: credential.public_key,
          sign_count: credential.sign_count,
          name: "Test Credential",
          authenticator_type: "platform",
        )

        # Simulate `UsersController#webauthn_options`
        get_options = WebAuthn::Credential.options_for_get(
          allow: user.webauthn_credentials.pluck(:webauthn_id),
          user_verification: "discouraged"
        )
        session[:webauthn_challenge] = get_options.challenge

        # Retrieve a credential (this logic is performed in the browser)
        # See `app/javascript/controllers/webauthn_auth_controller.js`
        get_payload = webauthn_client.get(challenge: get_options.challenge)

        expect {
          post(
            :complete,
            params: {
              id: login.hashid,
              method: "webauthn",
              credential: JSON.dump(get_payload)
            }
          )
        }.to change { webauthn_credential.reload.sign_count }.by(1)

        expect(response).to redirect_to(root_path)

        login.reload
        expect(login).to be_complete
        expect(login.authenticated_with_webauthn).to eq(true)
        expect(login.user_session).to be_present
        expect(current_session!).to eq(login.user_session)
      end
    end

    context "login_code" do
      context "email" do
        it "rejects invalid login codes" do
          user = create(:user)
          login = create(:login, user:)

          post(
            :complete,
            params: {
              id: login.hashid,
              method: "login_code",
              login_code: "123-456"
            }
          )

          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.body).to include("Invalid login code")
        end

        it "signs the user in and redirects" do
          user = create( :user, phone_number: "+18556254225" )
          login = create(:login, user:)
          login_code = create(:login_code, user:)

          post(
            :complete,
            params: {
              id: login.hashid,
              method: "login_code",
              login_code: login_code.code
            }
          )

          expect(response).to redirect_to(root_path)

          login.reload
          expect(login).to be_complete
          expect(login.authenticated_with_email).to eq(true)
          expect(login.user_session).to be_present
          expect(current_session!).to eq(login.user_session)

          login_code.reload
          expect(login_code).not_to be_active
        end
      end

      context "sms" do
        it "rejects invalid sms codes" do
          user = create(:user, phone_number: "+18556254225")
          login = create(:login, user:)

          # Stub out the SMS service
          verification_service = instance_double(TwilioVerificationService)
          expect(verification_service).to(
            receive(:check_verification_token)
              .with(user.phone_number, "123456")
              .and_return(false)
          )
          expect(TwilioVerificationService).to receive(:new).and_return(verification_service)

          post(
            :complete,
            params: {
              id: login.hashid,
              method: "login_code",
              login_code: "123-456",
              sms: "1",
            }
          )

          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.body).to include("Invalid login code")
        end

        it "signs the user in and redirects" do
          user = create(:user, phone_number: "+18556254225")
          login = create(:login, user:)

          # Stub out the SMS service
          verification_service = instance_double(TwilioVerificationService)
          expect(verification_service).to(
            receive(:check_verification_token)
              .with(user.phone_number, "123456")
              .and_return(true)
          )
          expect(TwilioVerificationService).to receive(:new).and_return(verification_service)

          post(
            :complete,
            params: {
              id: login.hashid,
              method: "login_code",
              login_code: "123-456",
              sms: "1",
            }
          )

          expect(response).to redirect_to(root_path)

          login.reload
          expect(login).to be_complete
          expect(login.authenticated_with_sms).to eq(true)
          expect(login.user_session).to be_present
          expect(current_session!).to eq(login.user_session)
        end
      end
    end

    context "totp" do
      it "rejects invalid totp codes" do
        user = create(:user)
        login = create(:login, user:)

        post(
          :complete,
          params: {
            id: login.hashid,
            method: "totp",
            code: "123456"
          }
        )

        expect(response).to redirect_to(totp_login_path(login))
        expect(flash[:error]).to include("Invalid TOTP code")
      end

      it "signs the user in and redirects" do
        freeze_time do
          user = create(:user, phone_number: "+18556254225")
          totp = user.create_totp!
          code = ROTP::TOTP.new(totp.secret, issuer: User::Totp::ISSUER).at(Time.now)
          login = create(:login, user:)

          post(
            :complete,
            params: {
              id: login.hashid,
              method: "totp",
              code:
            }
          )

          expect(response).to redirect_to(root_path)

          login.reload
          expect(login).to be_complete
          expect(login.authenticated_with_totp).to eq(true)
          expect(login.user_session).to be_present
          expect(current_session!).to eq(login.user_session)

          totp.reload
          expect(totp.last_used_at).to eq(Time.now)
        end
      end
    end

    context "2fa" do
      it "requests a second factor if 2fa is enabled" do
        user = create(:user, phone_number: "+18556254225", use_two_factor_authentication: true)
        totp = user.create_totp!
        login = create(:login, user:)
        login_code = create(:login_code, user:)

        post(
          :complete,
          params: {
            id: login.hashid,
            method: "login_code",
            login_code: login_code.code
          }
        )

        expect(response).to redirect_to(totp_login_path(login))

        login.reload
        expect(login).not_to be_complete
        expect(login.authenticated_with_email).to be(true)

        code = ROTP::TOTP.new(totp.secret, issuer: User::Totp::ISSUER).at(Time.now)

        post(
          :complete,
          params: {
            id: login.hashid,
            method: "totp",
            code:
          }
        )

        expect(response).to redirect_to(root_path)

        login.reload
        expect(login).to be_complete
        expect(login.authenticated_with_totp).to eq(true)
        expect(login.user_session).to be_present
        expect(current_session!).to eq(login.user_session)
      end
    end
  end

  it "redirects to the user's settings page if they don't have a name or phone number" do
    user = create(:user, full_name: nil, phone_number: nil)
    login = create(:login, user:)
    login_code = create(:login_code, user:)

    post(
      :complete,
      params: {
        id: login.hashid,
        method: "login_code",
        login_code: login_code.code
      }
    )

    expect(response).to redirect_to(edit_user_path(user.slug))
  end
end
