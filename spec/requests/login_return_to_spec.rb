# frozen_string_literal: true

require "rails_helper"

# Exercises the promise that clicking a link while signed out lands you back on
# that link once you've authenticated, across every branch of the login flow.
RSpec.describe "Login return_to", type: :request do
  include WebAuthnSupport

  let(:destination) { "/my/cards" }
  # `#complete` sends users with an incomplete profile to their settings page
  # instead of `return_to`, so give the user a phone number unless the example
  # is specifically about that branch.
  let(:user) { create(:user, phone_number: "+18556254225") }

  # Walks the email-code flow the way a browser would.
  def submit_email(email:, return_to: destination)
    post logins_path, params: { email:, login: { return_to: } }
    Login.order(:id).last
  end

  def submit_login_code(login, user)
    login_code = create(:login_code, user:)
    post complete_login_path(login), params: { method: "email", login_code: login_code.code }
  end

  # Finds a link by the text it renders, so the badge and the "Sign out" link
  # on the same page can be told apart.
  def link_named(text)
    response.parsed_body.css("a").find { |a| a.text.strip.include?(text) }
  end

  # The "signed in as" badge, which doubles as the switch-accounts link.
  def badge_link
    response.parsed_body.at_css("a:has([aria-label='Switch account'])")
  end

  # Turns off the bypass that lets specs drive logins without a real browser,
  # so the browser token actually has to match.
  def enforcing_browser_token
    Rails.configuration.x.skip_login_browser_token_check = false
    yield
  ensure
    Rails.configuration.x.skip_login_browser_token_check = true
  end

  describe "arriving at the login page" do
    it "carries the requested page over as return_to" do
      get destination

      expect(response).to redirect_to(
        auth_users_path(return_to: "http://www.example.com#{destination}", require_reload: true)
      )
    end

    # `webauthn_auth_controller.js` reads this field to forward `return_to` when
    # it posts a passkey assertion to the collection route.
    it "puts return_to in the login form" do
      get auth_users_path(return_to: destination)

      expect(response.parsed_body.at_css("input[name='login[return_to]']")[:value]).to eq(destination)
    end

    it "keeps return_to on the link to the other sign in methods" do
      get auth_users_path(return_to: destination)

      expect(link_named("Sign in another way")[:href]).to eq(
        choose_login_preference_logins_path(return_to: destination)
      )
    end

    it "omits return_to for the dashboard" do
      get "/"

      expect(response).to redirect_to(auth_users_path(require_reload: true))
    end
  end

  describe "signing in with an email code" do
    it "returns to the requested page" do
      login = submit_email(email: user.email)
      submit_login_code(login, user)

      expect(response).to redirect_to(destination)
    end

    it "returns to an absolute URL on the same host" do
      login = submit_email(email: user.email, return_to: "http://www.example.com#{destination}")
      submit_login_code(login, user)

      expect(response).to redirect_to("http://www.example.com#{destination}")
    end

    it "refuses to store or follow a return_to pointing at another host" do
      login = submit_email(email: user.email, return_to: "https://evil.example.com/steal")

      expect(login.return_to).to be_nil

      submit_login_code(login, user)

      expect(response).to redirect_to(root_path)
    end

    it "falls back to the dashboard rather than looping back to the login page" do
      login = submit_email(email: user.email, return_to: auth_users_path)
      submit_login_code(login, user)

      expect(response).to redirect_to(root_path)
    end

    it "drops a return_to too long to have come from a browser" do
      login = submit_email(email: user.email, return_to: "/#{"a" * 3.kilobytes}")

      expect(login.return_to).to be_nil

      submit_login_code(login, user)

      expect(response).to redirect_to(root_path)
    end
  end

  describe "signing in with a passkey from the login page" do
    it "returns to the requested page" do
      create_webauthn_credential(user:)

      # `logins/new` has no persisted login yet, so the Stimulus controller
      # posts to the collection route with the form's return_to.
      get "/users/webauthn/auth_options", params: { email: user.email }
      challenge = response.parsed_body["challenge"]

      post complete_logins_path, params: {
        method: "webauthn",
        credential: get_webauthn_credential(challenge:).to_json,
        return_to: destination
      }

      expect(response).to redirect_to(destination)
    end
  end

  describe "choosing a different sign in method from the login page" do
    it "keeps return_to on the login it starts" do
      # The "Sign in another way" link is only revealed after the passkey
      # lookup, which is what seeds `session[:auth_email]`.
      get "/users/webauthn/auth_options", params: { email: user.email }

      get choose_login_preference_logins_path(return_to: destination)

      expect(Login.order(:id).last.return_to).to eq(destination)
    end

    it "returns to the requested page after picking a method" do
      get "/users/webauthn/auth_options", params: { email: user.email }
      get choose_login_preference_logins_path(return_to: destination)

      login = Login.order(:id).last
      post set_login_preference_login_path(login), params: { login_preference: "email" }
      submit_login_code(login, user)

      expect(response).to redirect_to(destination)
    end

    it "starts over rather than erroring when the remembered email has no user" do
      get "/users/webauthn/auth_options", params: { email: "nobody@example.invalid" }

      get choose_login_preference_logins_path(return_to: destination)

      expect(response).to redirect_to(auth_users_path(return_to: destination))
    end
  end

  describe "cancelling part way through a login" do
    it "offers a Cancel link that keeps return_to" do
      get "/users/webauthn/auth_options", params: { email: user.email }
      get choose_login_preference_logins_path(return_to: destination)

      expect(link_named("Cancel")[:href]).to eq(logout_users_path(return_to: destination))
    end

    it "goes back to the login page with return_to intact" do
      submit_email(email: user.email)

      # "Cancel" signs out, but there's no session to sign out of yet.
      delete logout_users_path, params: { return_to: destination }

      expect(response).to redirect_to(auth_users_path(return_to: destination))
    end

    it "keeps return_to on the badge that switches accounts mid-login" do
      # The badge only renders once a previous sign in has left the avatar
      # cookie behind, and mid-login the visitor isn't signed in yet.
      first_login = submit_email(email: user.email, return_to: nil)
      submit_login_code(first_login, user)
      delete logout_users_path

      login = submit_email(email: user.email)
      post email_login_path(login)

      expect(badge_link[:href]).to eq(auth_users_path(return_to: destination))
    end
  end

  describe "signing in with two factors" do
    it "returns to the requested page only once both factors are met" do
      freeze_time

      totp = user.create_totp!
      user.update!(use_two_factor_authentication: true)

      login = submit_email(email: user.email)
      submit_login_code(login, user)

      expect(response).to redirect_to(choose_login_preference_login_path(login))

      post set_login_preference_login_path(login), params: { login_preference: "totp" }
      expect(response).to redirect_to(totp_login_path(login))

      post complete_login_path(login), params: {
        method: "totp",
        code: ROTP::TOTP.new(totp.secret, issuer: User::Totp::ISSUER).now
      }

      expect(response).to redirect_to(destination)
    end
  end

  describe "opening an invite while signed in as the wrong account" do
    it "offers a sign out that comes back to the invite" do
      login = submit_email(email: user.email)
      submit_login_code(login, user)

      get auth_users_path(return_to: destination, error: "unauthorised_card_grant")

      expect(link_named("Sign out")[:href]).to eq(logout_users_path(return_to: destination))
    end
  end

  describe "when the user is missing a phone number" do
    let(:user) { create(:user, full_name: "Fiona Hackworth", phone_number: nil) }

    before do
      login = submit_email(email: user.email)
      submit_login_code(login, user)
    end

    it "sends them to their settings with return_to" do
      expect(response).to redirect_to(edit_user_path(user.slug, return_to: destination))
    end

    it "renders a return_to field so the browser sends it back" do
      follow_redirect!

      expect(response.parsed_body.at_css("form input[name='return_to']")[:value]).to eq(destination)
    end

    it "returns to the requested page once they've added one" do
      patch user_path(user), params: {
        return_to: destination,
        user: { phone_number: "+18556254225" }
      }

      expect(response).to redirect_to(destination)
    end

    it "does not send them off to another host" do
      patch user_path(user), params: {
        return_to: "https://evil.example.com/steal",
        user: { phone_number: "+18556254225" }
      }

      expect(response).to redirect_to(edit_user_path(user))
    end
  end

  describe "when return_to points back at the login page" do
    let(:user) { create(:user, full_name: "Fiona Hackworth", phone_number: nil) }

    it "does not bounce a user finishing their profile back into signing in" do
      login = submit_email(email: user.email, return_to: auth_users_path)
      submit_login_code(login, user)

      expect(response).to redirect_to(edit_user_path(user.slug))

      patch user_path(user), params: { user: { phone_number: "+18556254225" } }

      expect(response).not_to redirect_to(auth_users_path)
    end
  end

  describe "when the user has no profile yet" do
    let(:user) { create(:user, full_name: nil, phone_number: nil) }

    it "returns to the requested page once they've created one" do
      login = submit_email(email: user.email)
      submit_login_code(login, user)

      expect(response).to redirect_to(edit_user_path(user.slug, return_to: destination))

      patch user_path(user), params: {
        return_to: destination,
        user: { full_name: "Fiona Hackworth", phone_number: "+18556254225" }
      }

      expect(response).to redirect_to(destination)
    end
  end

  describe "when already signed in" do
    before do
      login = submit_email(email: user.email)
      submit_login_code(login, user)
    end

    it "offers a sign out link that keeps return_to" do
      get auth_users_path(return_to: destination)

      expect(link_named("Sign out")[:href]).to eq(logout_users_path(return_to: destination))
    end

    it "keeps return_to on the badge that switches accounts" do
      get auth_users_path(return_to: destination)

      expect(badge_link[:href]).to eq(logout_users_path(return_to: destination))
    end

    it "sends them back to the login page with return_to after signing out" do
      delete logout_users_path, params: { return_to: destination }

      expect(response).to redirect_to(auth_users_path(return_to: destination))
    end

    it "sends them to the dashboard when there is nowhere to return to" do
      delete logout_users_path

      expect(response).to redirect_to(root_path)
    end
  end

  describe "when the login is restarted" do
    it "keeps return_to after the login expires" do
      login = submit_email(email: user.email)

      travel(Login::EXPIRATION + 1.minute) do
        submit_login_code(login, user)
      end

      expect(response).to redirect_to(auth_users_path(return_to: destination))
    end

    it "keeps return_to when the account is locked" do
      login = submit_email(email: user.email)
      user.lock!

      submit_login_code(login, user)

      expect(flash[:error]).to eq("Your HCB account has been locked.")
      expect(response).to redirect_to(auth_users_path(return_to: destination))
    end

    it "keeps the requested return_to when the login id is unknown" do
      post "/logins/nonsense/complete", params: {
        method: "email",
        login_code: "123456",
        return_to: destination
      }

      expect(response).to redirect_to(auth_users_path(return_to: destination))
    end

    it "keeps return_to when a passkey assertion fails" do
      # A passkey belonging to somebody else, so verification rejects it.
      stranger = create(:user)
      create_webauthn_credential(user: stranger)
      credential = get_webauthn_credential(challenge: generate_webauthn_challenge(user: stranger))

      login = submit_email(email: user.email)

      post complete_login_path(login), params: {
        method: "webauthn",
        credential: credential.to_json
      }

      expect(flash[:error]).to eq("Invalid security key")
      expect(response).to redirect_to(auth_users_path(return_to: destination))
    end

    it "keeps return_to when the email address is rejected" do
      post logins_path, params: { email: "not-an-email", login: { return_to: destination } }

      expect(response).to redirect_to(auth_users_path(return_to: destination))
    end
  end

  # Login hashids are salted with an empty string, so they can be computed
  # rather than guessed. Nothing about a login may leak to a browser that
  # can't produce the token it was started with.
  describe "when a different browser presents someone else's login id" do
    it "still enforces the browser token when the bypass is unconfigured" do
      login = submit_email(email: user.email)

      # An unset `config.x` key reads back as an empty `OrderedOptions`, which
      # is truthy. Reading it as "skip the check" would disable this in every
      # environment that doesn't set it.
      unset = ActiveSupport::OrderedOptions.new
      Rails.configuration.x.skip_login_browser_token_check = unset
      begin
        reset!
        post complete_login_path(login), params: { method: "email", login_code: "123456" }
      ensure
        Rails.configuration.x.skip_login_browser_token_check = true
      end

      expect(response).to redirect_to(auth_users_path)
    end

    it "refuses to hand over the expired login's return_to" do
      login = submit_email(email: user.email)

      enforcing_browser_token do
        # A fresh session: no browser token cookie for this login.
        reset!
        travel(Login::EXPIRATION + 1.minute) do
          post complete_login_path(login), params: { method: "email", login_code: "123456" }
        end
      end

      expect(response).to redirect_to(auth_users_path)
    end

    it "refuses to hand over a live login's return_to" do
      login = submit_email(email: user.email)

      enforcing_browser_token do
        reset!
        post complete_login_path(login), params: { method: "email", login_code: "123456" }
      end

      expect(response).to redirect_to(auth_users_path)
    end

    it "refuses to hand over the return_to of a login with no browser token" do
      login = submit_email(email: user.email)
      login.update_column(:browser_token_ciphertext, nil)

      travel(Login::EXPIRATION + 1.minute) do
        post complete_login_path(login), params: { method: "email", login_code: "123456" }
      end

      expect(response).to redirect_to(auth_users_path)
    end
  end
end
