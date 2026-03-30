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

        initial_session = sign_in(admin_user)

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

    it "allows admins to impersonate locked accounts" do
      admin_user = create(:user, :make_admin)
      impersonated_user = create(:user, full_name: "Impersonated User")
      impersonated_user.lock!

      initial_session = sign_in(admin_user)

      post(:impersonate, params: { id: impersonated_user.id })
      expect(response).to redirect_to(root_path)
      expect(flash[:info]).to eq("You're now impersonating Impersonated User.")

      new_session = current_session!
      expect(new_session.user_id).to eq(impersonated_user.id)
      expect(new_session.impersonated_by_id).to eq(admin_user.id)
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
      sign_in(user)

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
      sign_in(user)

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

    it "does not allow saving an unsupported payout method" do
      reason = "Due to integration issues, transfers via PayPal are currently unavailable in tests."
      stub_const(
        "User::PayoutMethod::UNSUPPORTED_METHODS",
        {
          User::PayoutMethod::PaypalTransfer => {
            status_badge: "Unavailable",
            reason:
          },
        }
      )

      user = create(:user)
      sign_in(user)

      patch(
        :update,
        params: {
          id: user.id,
          user: {
            payout_method_type: "User::PayoutMethod::PaypalTransfer",
            payout_method_attributes: {
              recipient_email: "gary@hackclub.com"
            }
          }
        }
      )

      expect(response).to have_http_status(:unprocessable_entity)
      expect(flash.to_h).to eq("error" => "#{reason} Please choose another method.")
      expect(user.reload.payout_method_type).to eq(nil)
    end
  end
end
