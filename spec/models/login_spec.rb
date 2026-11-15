# frozen_string_literal: true

require "rails_helper"

RSpec.describe Login do
  describe "#complete?" do
    it "is true when 2fa is not enabled and one factor was used" do
      user = create(:user, use_two_factor_authentication: false)
      login = create(:login, user:)

      login.update!(authenticated_with_email: true)

      expect(login).to be_complete
    end

    it "is false when 2fa is enabled and one factor was used" do
      user = create(:user, use_two_factor_authentication: true, phone_number: "+18556254225", phone_number_verified: true, use_sms_auth: true)
      login = create(:login, user:)

      login.update!(authenticated_with_email: true)

      expect(login).not_to be_complete
    end

    it "is true when 2fa is enabled and two factors were used" do
      user = create(:user, use_two_factor_authentication: true, phone_number: "+18556254225", phone_number_verified: true, use_sms_auth: true)
      login = create(:login, user:)

      login.update!(authenticated_with_email: true)
      login.update!(authenticated_with_totp: true)

      expect(login).to be_complete
    end

    it "is true when the login is a reauthentication and one factor was used regardless of 2fa" do
      user = create(:user, use_two_factor_authentication: true, phone_number: "+18556254225", phone_number_verified: true, use_sms_auth: true)
      login = create(:login, user:, is_reauthentication: true)

      login.update!(authenticated_with_email: true)

      expect(login).to be_reauthentication
      expect(login).to be_complete
    end
  end

  describe "user_session validations" do
    let(:user) { create(:user, verified: true) }
    let(:verified_session) do
      User::Session.create!(
        user:,
        verified: true,
        session_token: SecureRandom.urlsafe_base64,
        expiration_at: 1.week.from_now,
      )
    end

    it "is valid when user_session is verified and belongs to the same user" do
      login = build(:login, user:, user_session: verified_session, authenticated_with_email: true, aasm_state: "complete")

      expect(login).to be_valid
    end

    it "rejects an unverified user_session" do
      unverified_user = create(:user, verified: false)
      unverified_session = User::Session.new(
        user: unverified_user,
        verified: false,
        session_token: SecureRandom.urlsafe_base64,
        expiration_at: 1.week.from_now,
      )
      unverified_session.save!(validate: false)

      login = build(:login, user: unverified_user, user_session: unverified_session, authenticated_with_email: true, aasm_state: "complete")

      expect(login).not_to be_valid
      expect(login.errors[:user_session]).to include("must be verified")
    end

    it "records a mismatch error when user_session belongs to a different user" do
      allow(Rails.error).to receive(:unexpected)

      other_user = create(:user, verified: true)
      session_for_other = User::Session.create!(
        user: other_user,
        verified: true,
        session_token: SecureRandom.urlsafe_base64,
        expiration_at: 1.week.from_now,
      )

      login = build(:login, user:, user_session: session_for_other, authenticated_with_email: true, aasm_state: "complete")

      expect(login).not_to be_valid
      expect(login.errors[:base]).to include(a_string_matching(/user_session\.user \/ user mismatch/))
      expect(Rails.error).to have_received(:unexpected).with(a_string_matching(/user_session\.user_id .* user_id .* mismatch/))
    end
  end
end
