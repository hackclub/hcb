# frozen_string_literal: true

require "rails_helper"

RSpec.describe "LoginsController", type: :request do
  let(:creator) { create(:user, verified: true) }
  let(:program) { Referral::Program.create!(name: "Referral test program", creator:) }
  let(:link)    { program.links.create!(name: "Primary", creator:) }

  # Rendering the login form is what writes invisible_captcha's session token,
  # so anything posting to /logins has to fetch it first, the way a browser does.
  def visit_login_form
    get auth_users_path
  end

  describe "POST /logins" do
    it "binds a prior referral click to the user signing in" do
      get "/referrals/#{link.slug}"
      attribution = Referral::Attribution.last
      expect(attribution.user).to be_nil

      email = "referred-#{SecureRandom.hex(4)}@example.invalid"
      visit_login_form
      post "/logins", params: { email:, login: { return_to: "/" } }

      user = User.find_by(email:)
      expect(user).to be_present
      expect(attribution.reload.user).to eq(user)
    end

    # `#create` rescues everything and redirects to the auth page, so a nil
    # session would surface as a confusing flash rather than a 500.
    it "completes for a visitor who never clicked a referral link and so has no session" do
      email = "direct-#{SecureRandom.hex(4)}@example.invalid"
      visit_login_form

      expect {
        post "/logins", params: { email:, login: { return_to: "/" } }
      }.to change { Login.count }.by(1)

      expect(response).not_to redirect_to(auth_users_path)
    end

    it "rejects a submission from a client that never rendered the form" do
      email = "scripted-#{SecureRandom.hex(4)}@example.invalid"

      expect {
        post "/logins", params: { email:, login: { return_to: "/" } }
      }.to change { Login.count }.by(0)

      expect(User.find_by(email:)).to be_nil
    end

    it "accepts a submission sent immediately after the form renders" do
      email = "autofilled-#{SecureRandom.hex(4)}@example.invalid"
      visit_login_form

      expect {
        post "/logins", params: { email:, login: { return_to: "/" } }
      }.to change { Login.count }.by(1)
    end
  end

  describe "POST /logins/:id/complete" do
    # The security key flow renders no form between `create` and `complete`, so
    # if `complete` enforced the timestamp there would be no session token left
    # and a passkey sign in would fail with no way to retry.
    it "reaches the action for a security key sign in" do
      user = create(:user, verified: true)
      visit_login_form
      post "/logins", params: { email: user.email, login: { return_to: "/" } }
      login = Login.last

      post "/logins/#{login.hashid}/complete", params: { method: "webauthn", credential: "not-a-real-credential" }

      expect(flash[:error]).to be_present
      expect(flash[:error]).not_to eq(InvisibleCaptcha.timestamp_error_message)
    end
  end
end
