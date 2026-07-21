# frozen_string_literal: true

require "rails_helper"

RSpec.describe "LoginsController", type: :request do
  let(:creator) { create(:user, verified: true) }
  let(:program) { Referral::Program.create!(name: "Referral test program", creator:) }
  let(:link)    { program.links.create!(name: "Primary", creator:) }

  describe "POST /logins" do
    it "binds a prior referral click to the user signing in" do
      get "/referrals/#{link.slug}"
      attribution = Referral::Attribution.last
      expect(attribution.user).to be_nil

      email = "referred-#{SecureRandom.hex(4)}@example.invalid"
      post "/logins", params: { email:, login: { return_to: "/" } }

      expect(attribution.reload.user).to eq(User.find_by(email:))
    end

    # `#create` rescues everything and redirects to the auth page, so a nil
    # session would surface as a confusing flash rather than a 500.
    it "completes for a visitor who never clicked a referral link and so has no session" do
      email = "direct-#{SecureRandom.hex(4)}@example.invalid"

      expect {
        post "/logins", params: { email:, login: { return_to: "/" } }
      }.to change { Login.count }.by(1)

      expect(response).not_to redirect_to(auth_users_path)
    end
  end
end
