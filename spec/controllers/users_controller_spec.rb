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
end
