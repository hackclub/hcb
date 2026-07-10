# frozen_string_literal: true

require "rails_helper"

RSpec.describe UsersController do
  include SessionSupport
  include TwilioSupport

  describe "#impersonate" do
    it "allows admins to switch to an impersonated session" do
      freeze_time do
        admin_user = create(:user, :make_admin, full_name: "Admin User")
        impersonated_user = create(:user, full_name: "Impersonated User")

        initial_session = create_session(admin_user, verified: true)

        # This is a normal session which should last for the user's session_validity_preference
        expect(initial_session.expiration_at).to eq(admin_user.session_validity_preference.seconds.from_now)

        post(:impersonate, params: { id: impersonated_user.id })
        expect(response).to redirect_to(root_path)
        expect(flash[:info]).to eq("You're now impersonating Impersonated User.")

        new_session = current_session!
        expect(new_session.id).not_to eq(initial_session.id) # make sure the session was replaced
        expect(new_session.user_id).to eq(impersonated_user.id)
        expect(new_session.impersonated_by_id).to eq(admin_user.id)
        expect(new_session.expiration_at).to eq(1.hour.from_now) # make sure we capped the session length
      end
    end

    it "allows admins to impersonate unverified accounts and mirrors the target's verification" do
      admin_user = create(:user, :make_admin)
      impersonated_user = create(:user, verified: false, creation_method: :first_robotics_form)

      create_session(admin_user, verified: true)

      post(:impersonate, params: { id: impersonated_user.id })
      expect(response).to redirect_to(root_path)

      new_session = current_session!
      expect(new_session.user_id).to eq(impersonated_user.id)
      expect(new_session.impersonated_by_id).to eq(admin_user.id)
      # Mirror the target's view: the admin sees what an unverified user sees,
      # i.e. an unverified session.
      expect(new_session.verified).to be(false)
    end

    it "allows admins to impersonate locked accounts" do
      admin_user = create(:user, :make_admin)
      impersonated_user = create(:user, full_name: "Impersonated User")
      impersonated_user.lock!

      create_session(admin_user, verified: true)

      post(:impersonate, params: { id: impersonated_user.id })
      expect(response).to redirect_to(root_path)
      expect(flash[:info]).to eq("You're now impersonating Impersonated User.")

      new_session = current_session!
      expect(new_session.user_id).to eq(impersonated_user.id)
      expect(new_session.impersonated_by_id).to eq(admin_user.id)
    end
  end

  describe "#suppress_card_locking" do
    it "lets an admin suppress card locking for a user" do
      freeze_time do
        admin_user = create(:user, :make_admin)
        user = create(:user)
        create_session(admin_user, verified: true)

        expect(User::UpdateCardLockingJob).to receive(:perform_later).with(user:)

        post(:suppress_card_locking, params: { id: user.id, hours: 48 })

        expect(response).to redirect_to(admin_user_path(user))
        expect(flash[:success]).to eq("Card locking suppressed for 48h.")
        expect(user.reload.card_locking_suppressed_until).to eq(48.hours.from_now)
      end
    end

    it "forbids a non-admin from suppressing card locking" do
      requester = create(:user)
      user = create(:user)
      create_session(requester, verified: true)

      expect(User::UpdateCardLockingJob).not_to receive(:perform_later)

      post(:suppress_card_locking, params: { id: user.id, hours: 48 })

      expect(flash[:error]).to eq("You are not authorized to perform this action.")
      expect(user.reload.card_locking_suppressed_until).to be_nil
    end
  end

  describe "#update" do
    render_views

    it "requires sudo mode in order to change 2fa settings" do
      user = create(:user, phone_number: "+18556254225")
      user.update!(phone_number_verified: true)
      user.update!(use_sms_auth: true)
      user.update!(use_two_factor_authentication: true)
      Flipper.enable(:sudo_mode_2015_07_21, user)
      stub_twilio_sms_verification(phone_number: user.phone_number, code: "123456")
      create_session(user, verified: true)

      travel_to(3.hours.from_now)

      patch(
        :update,
        params: {
          id: user.id,
          user: { use_two_factor_authentication: false }
        }
      )

      expect(response).to have_http_status(:unauthorized)
      expect(response.body).to include("Confirm Access")
      expect(user.reload.use_two_factor_authentication).to eq(true)

      patch(
        :update,
        params: {
          id: user.id,
          user: { use_two_factor_authentication: false },
          _sudo: {
            submit_method: "sms",
            login_code: "123456",
            login_id: user.logins.last.hashid,
          }
        }
      )

      expect(response).to have_http_status(:found)
      expect(user.reload.use_two_factor_authentication).to eq(false)
    end

    it "does not require sudo mode unless the feature flag is enabled" do
      user = create(:user, phone_number: "+18556254225")
      user.update!(phone_number_verified: true)
      user.update!(use_sms_auth: true)
      user.update!(use_two_factor_authentication: true)
      Flipper.disable(:sudo_mode_2015_07_21, user)
      create_session(user, verified: true)

      travel_to(3.hours.from_now)

      patch(
        :update,
        params: {
          id: user.id,
          user: { use_two_factor_authentication: false }
        }
      )

      expect(response).to have_http_status(:found)
      expect(user.reload.use_two_factor_authentication).to eq(false)
    end

    it "saves the chosen payout method as the user's default legal entity payout method" do
      user = create(:user)
      create_session(user, verified: true)

      patch(
        :update,
        params: {
          id: user.id,
          user: {
            payout_method_type: "LegalEntity::PayoutMethod::AchTransfer",
            payout_method_attributes: {
              account_number: "12345678",
              routing_number: "021000021"
            }
          }
        }
      )

      expect(response).to have_http_status(:found)
      default = user.reload.default_payout_method
      expect(default).to be_present
      expect(default).to be_default
      expect(default.details).to be_a(LegalEntity::PayoutMethod::AchTransfer)
      expect(default.details.routing_number).to eq("021000021")
    end

    it "does not allow saving an unsupported payout method" do
      reason = "Checks are paused in tests."
      stub_const(
        "LegalEntity::PayoutMethod::UNSUPPORTED_METHODS",
        {
          LegalEntity::PayoutMethod::Check => {
            status_badge: "Unavailable",
            reason:
          },
        }
      )

      user = create(:user)
      create_session(user, verified: true)

      patch(
        :update,
        params: {
          id: user.id,
          user: {
            payout_method_type: "LegalEntity::PayoutMethod::Check",
            payout_method_attributes: {
              address_line1: "1 Main St",
              address_city: "New York",
              address_state: "NY",
              address_postal_code: "10001"
            }
          }
        }
      )

      expect(response).to have_http_status(:unprocessable_entity)
      expect(flash.to_h["error"]).to include(reason)
      expect(user.reload.default_payout_method).to be_nil
    end
  end

  describe "settings access for unverified users" do
    def sign_in_unverified
      user = create(:user, verified: false)
      user_session = User::Session.create!(
        user:,
        verified: false,
        session_token: SecureRandom.urlsafe_base64,
        expiration_at: 7.days.from_now,
      )
      cookies.encrypted[:session_token] = {
        value: user_session.session_token,
        expires: User::Session::MAX_SESSION_DURATION.from_now,
        httponly: true,
      }
      user_session
    end

    settings_actions = %i[
      edit
      edit_address
      edit_payout
      edit_featurepreviews
      edit_security
      edit_notifications
      edit_integrations
      edit_admin
    ]

    settings_actions.each do |action|
      it "redirects ##{action} to the auth page" do
        sign_in_unverified

        get(action)

        expect(response).to redirect_to(/\/users\/auth/)
      end
    end
  end
end
