# frozen_string_literal: true

require "rails_helper"

RSpec.describe SudoModeHandler do
  include SessionSupport
  include WebAuthnSupport
  render_views(true)

  controller(ApplicationController) do
    skip_after_action :verify_authorized
    before_action :enforce_sudo_mode

    def index
      render(status: :ok, plain: "Index")
    end

    def create
      render(status: :created, plain: "Created")
    end
  end

  def logged_in_context(user: nil, at: 1.day.ago, feature_enabled: true)
    travel_to(at) do
      user ||= create(:user)
      Flipper.enable(:sudo_mode_2015_07_21, user) if feature_enabled

      user_session = sign_in(user)

      { user:, user_session: }
    end
  end

  context "when the user has sudo mode" do
    it "allows the request to proceed" do
      logged_in_context(at: Time.zone.now)

      post(:create)
      expect(response).to have_http_status(:created)
    end
  end

  context "when the user does not have sudo mode" do
    def extract_submit_method(response)
      response
        .parsed_body
        .css("[name='_sudo[submit_method]']")
        .sole
        .attr("value")
    end

    def stub_login_code_service(email:, sms:)
      login_code_service = instance_double(LoginCodeService::Request)
      expect(login_code_service).to receive(:run)

      expect(LoginCodeService::Request).to receive(:new).with(
        email:,
        sms:,
        ip_address: "0.0.0.0",
        user_agent: "Rails Testing",
      ).and_return(login_code_service)
    end

    it "intercepts the request and renders the reauthentication page" do
      logged_in_context

      post(:create)

      expect(response).to have_http_status(:unauthorized)
      expect(response.body).to include("Confirm Access")

      form = response.parsed_body.css("form").sole
      expect(form.attr("action")).to eq("/anonymous")
      expect(form.attr("method")).to eq("post")
    end

    it "allows the request to proceed if the user does not have the feature enabled" do
      logged_in_context(feature_enabled: false)

      post(:create)

      expect(response).to have_http_status(:created)
    end

    it "sends an email code by default" do
      logged_in_context => { user: }
      stub_login_code_service(email: user.email, sms: false)

      post(:create)

      expect(response).to have_http_status(:unauthorized)
      expect(response.body).to include("Confirm Access")
      expect(extract_submit_method(response)).to eq("email")
    end

    it "sends an SMS if the user has a confirmed phone number" do
      user = create(:user, phone_number: "+18556254225")
      user.update!(phone_number_verified: true)
      logged_in_context(user:)

      stub_login_code_service(email: user.email, sms: true)

      post(:create)

      expect(response).to have_http_status(:unauthorized)
      expect(response.body).to include("Confirm Access")
      expect(extract_submit_method(response)).to eq("sms")
    end

    it "honors the user's preferred login method" do
      user = create(:user, phone_number: "+18556254225")
      user.update!(phone_number_verified: true)
      logged_in_context(user:)

      session[:login_preference] = "email"

      stub_login_code_service(email: user.email, sms: false)

      post(:create)

      expect(response).to have_http_status(:unauthorized)
      expect(response.body).to include("Confirm Access")
      expect(extract_submit_method(response)).to eq("email")
    end

    it "switches the login method if the param is set" do
      user = create(:user, phone_number: "+18556254225")
      user.update!(phone_number_verified: true)
      logged_in_context(user:)

      stub_login_code_service(email: user.email, sms: false)

      post(:create, params: { _sudo: { switch_method: "email" } })

      expect(response).to have_http_status(:unauthorized)
      expect(response.body).to include("Confirm Access")
      expect(extract_submit_method(response)).to eq("email")
    end

    it "displays additional options when available" do
      # Create a user with SMS auth available
      user = create(:user, phone_number: "+18556254225")
      user.update!(phone_number_verified: true)

      # Enable backup codes (to make sure they aren't rendered)
      user.generate_backup_codes!
      user.activate_backup_codes!

      # Enable TOTP
      user.create_totp!

      # Enable WebAuthn
      create_webauthn_credential(user:)

      logged_in_context(user:)

      expect(LoginCodeService::Request).not_to receive(:new)

      post(:create)

      expect(response).to have_http_status(:unauthorized)
      expect(response.body).to include("Confirm Access")

      # If there isn't an explicit user preference we favor WebAuthn
      expect(extract_submit_method(response)).to eq("webauthn")

      additional_factor_buttons = response.parsed_body.css("[name='_sudo[switch_method]']")
      expect(additional_factor_buttons.map { |el| el.text.strip }).to eq(
        [
          "Use a one-time password",
          "Get a login code by SMS",
          "Get a login code by email"
        ]
      )
    end

    it "includes the original request parameters in the form" do
      logged_in_context

      params = {
        "users"              => {
          "1" => { "name" => "Orpheus", "tags" => ["dinosaur", "hack clubber"] },
          "2" => { "name" => "Blåhaj", "settings" => { "emoji" => "🦈" } },
        },
        # These should be ignored
        "authenticity_token" => "token",
        "_method"            => "POST",
      }

      post(:create, params:)

      expect(response).to have_http_status(:unauthorized)
      expect(response.body).to include("Confirm Access")

      form_params =
        response
        .parsed_body
        .css("form [name]")
        .map { |el| [el.attr("name"), el.attr("value")] }
        .reject { |(name, _)| name.start_with?("_sudo") }

      expect(form_params).to eq(
        [
          ["users[1][name]", "Orpheus"],
          ["users[1][tags][]", "dinosaur"],
          ["users[1][tags][]", "hack clubber"],
          ["users[2][name]", "Blåhaj"],
          ["users[2][settings][emoji]", "🦈"],
        ]
      )
    end

    it "intercepts GET requests via a different endpoint" do
      logged_in_context

      get(:index, params: { q: "dinosaurs", sort_by: "name", sort_direction: "asc" })

      expect(response).to have_http_status(:unauthorized)
      expect(response.body).to include("Confirm Access")

      form = response.parsed_body.css("form").sole
      expect(form.attr("action")).to eq(reauthenticate_logins_path)
      expect(form.attr("method")).to eq("post")

      form_params =
        response
        .parsed_body
        .css("form [name]")
        .map { |el| [el.attr("name"), el.attr("value")] }
        .reject { |(name, _)| name.start_with?("_sudo") }

      expect(form_params).to eq(
        [
          ["return_to", "/anonymous?q=dinosaurs&sort_by=name&sort_direction=asc"]
        ]
      )
    end

    it "creates a new login" do
      logged_in_context => { user: }

      post(:create)

      expect(response).to have_http_status(:unauthorized)
      expect(response.body).to include("Confirm Access")

      login_id = response.parsed_body.css("[name='_sudo[login_id]']").sole.attr("value")
      login = Login.find_by_hashid!(login_id)

      expect(login.user).to eq(user)
      expect(login.is_reauthentication).to eq(true)
      expect(login).to be_incomplete
    end
  end

  context "when the reauthentication form is submitted" do
    it "errors if the login_id invalid" do
      logged_in_context

      post(:create, params: { _sudo: { login_id: "nope", submit_method: "email" } })

      expect(response).to have_http_status(:unauthorized)
      expect(response.body).to include("Confirm Access")
      expect(flash[:error]).to eq("Login has expired. Please try again.")
    end

    it "errors if the login id is for an initial login" do
      logged_in_context => { user: }
      login = create(:login, user:, is_reauthentication: false)

      post(:create, params: { _sudo: { login_id: login.hashid, submit_method: "email" } })

      expect(response).to have_http_status(:unauthorized)
      expect(response.body).to include("Confirm Access")
      expect(flash[:error]).to eq("Login has expired. Please try again.")

    end

    def stub_login_service(&)
      expect(ProcessLoginService).to(
        receive(:new)
          .and_invoke(
            ->(login:) {
              instance_double(ProcessLoginService).tap do |instance|
                yield(instance, login)
              end
            }
          )
      )
    end

    it "handles email codes" do
      logged_in_context => { user:, user_session: }
      login = create(:login, user:, is_reauthentication: true)

      stub_login_service do |instance, service_login|
        expect(instance).to(
          receive(:process_login_code)
            .with(code: "123-456", sms: false)
            .and_invoke(->(**) { service_login.update!(authenticated_with_email: true) })
        )
      end

      post(
        :create,
        params: {
          _sudo: {
            login_id: login.hashid,
            submit_method: "email",
            login_code: "123-456"
          }
        }
      )

      expect(response).to have_http_status(:created)
      expect(login.reload).to be_complete
      expect(user_session.reload).to be_sudo_mode
    end

    it "handles sms codes" do
      logged_in_context => { user:, user_session: }
      login = create(:login, user:, is_reauthentication: true)

      stub_login_service do |instance, service_login|
        expect(instance).to(
          receive(:process_login_code)
            .with(code: "123-456", sms: true)
            .and_invoke(->(**) { service_login.update!(authenticated_with_sms: true) })
        )
      end

      post(
        :create,
        params: {
          _sudo: {
            login_id: login.hashid,
            submit_method: "sms",
            login_code: "123-456"
          }
        }
      )

      expect(response).to have_http_status(:created)
      expect(login.reload).to be_complete
      expect(user_session.reload).to be_sudo_mode
    end

    it "handles totp codes" do
      logged_in_context => { user:, user_session: }
      login = create(:login, user:, is_reauthentication: true)

      stub_login_service do |instance, service_login|
        expect(instance).to(
          receive(:process_totp)
            .with(code: "123-456")
            .and_invoke(->(**) { service_login.update!(authenticated_with_totp: true) })
        )
      end

      post(
        :create,
        params: {
          _sudo: {
            login_id: login.hashid,
            submit_method: "totp",
            login_code: "123-456"
          }
        }
      )

      expect(response).to have_http_status(:created)
      expect(login.reload).to be_complete
      expect(user_session.reload).to be_sudo_mode
    end

    it "handles webauthn" do
      logged_in_context => { user:, user_session: }
      login = create(:login, user:, is_reauthentication: true)

      session[:webauthn_challenge] = "WEBAUTHN_CHALLENGE"

      stub_login_service do |instance, service_login|
        expect(instance).to(
          receive(:process_webauthn)
            .with(
              raw_credential: "{\"test\": \"webauthn_response\"}",
              challenge: "WEBAUTHN_CHALLENGE",
            )
            .and_invoke(->(**) { service_login.update!(authenticated_with_webauthn: true) })
        )
      end

      post(
        :create,
        params: {
          _sudo: {
            login_id: login.hashid,
            submit_method: "webauthn",
            webauthn_response: "{\"test\": \"webauthn_response\"}",
          }
        }
      )

      expect(response).to have_http_status(:created)
      expect(login.reload).to be_complete
      expect(user_session.reload).to be_sudo_mode
    end

    it "rejects invalid methods" do
      logged_in_context => { user:, user_session: }
      login = create(:login, user:, is_reauthentication: true)

      expect do
        post(
          :create,
          params: {
            _sudo: {
              login_id: login.hashid,
              submit_method: "lol",
              login_code: "123-456"
            }
          }
        )
      end.to raise_error(ActionController::ParameterMissing, "param is missing or the value is empty or invalid: submit_method")

      expect(login.reload).not_to be_complete
      expect(user_session.reload).not_to be_sudo_mode
    end

    it "handles login failures" do
      logged_in_context => { user: }
      login = create(:login, user:, is_reauthentication: true)

      stub_login_service do |instance, _service_login|
        expect(instance).to(
          receive(:process_login_code)
            .with(code: "123-456", sms: false)
            .and_return(false)
        )

        errors = ActiveModel::Errors.new(Object.new)
        errors.add(:base, "Turn it off and on again")

        expect(instance).to receive(:errors).and_return(errors)
      end

      post(
        :create,
        params: {
          _sudo: {
            login_id: login.hashid,
            submit_method: "email",
            login_code: "123-456"
          }
        }
      )

      expect(response).to have_http_status(:unauthorized)
      expect(response.body).to include("Confirm Access")
      expect(flash[:error]).to eq("Turn it off and on again")
    end
  end
end
