# frozen_string_literal: true

require "rails_helper"

RSpec.describe UsersController do
  include SessionSupport

  describe "#impersonate" do
    it "allows admins to switch to an impersonated session" do
      freeze_time do
        # Manually set a long session expiration so we can make sure
        # impersonated sessions are short
        session_duration_seconds = 30.days.seconds.to_i

        admin_user = create(:user, :make_admin, full_name: "Admin User", session_duration_seconds:)
        impersonated_user = create(:user, full_name: "Impersonated User", session_duration_seconds:)

        initial_session = sign_in(admin_user)

        # This is a normal session which should last for the duration that the
        # user configured
        expect(initial_session.expiration_at).to eq(30.days.from_now)

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
  end

  describe "#update" do
    render_views

    it "requires sudo mode in order to change 2fa settings" do
      user = create(
        :user,
        use_two_factor_authentication: true,
        phone_number: "+18556254225",
      )
      user.update!(phone_number_verified: true)
      Flipper.enable(:sudo_mode_2015_07_21, user)
      sign_in(user)

      travel_to(3.hours.from_now)

      patch(
        :update,
        params: {
          id: user.id,
          user: { use_two_factor_authentication: false }
        }
      )

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Confirm Access")
      expect(user.reload.use_two_factor_authentication).to eq(true)

      patch(
        :update,
        params: {
          id: user.id,
          user: { use_two_factor_authentication: false },
          _sudo: {
            submit_method: "email",
            login_code: user.login_codes.last.code,
            login_id: user.logins.last.hashid,
          }
        }
      )

      expect(response).to have_http_status(:found)
      expect(user.reload.use_two_factor_authentication).to eq(false)
    end

    it "does not require sudo mode unless the feature flag is enabled" do
      user = create(
        :user,
        use_two_factor_authentication: true,
        phone_number: "+18556254225",
      )
      user.update!(phone_number_verified: true)
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
  end
end
