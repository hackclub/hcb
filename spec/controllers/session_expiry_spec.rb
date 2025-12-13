# frozen_string_literal: true

require "rails_helper"

RSpec.describe("session expiry", type: :controller) do
  include SessionSupport
  render_views

  controller(ApplicationController) do
    skip_after_action(:verify_authorized)

    def index
      render(status: :ok, plain: "index")
    end
  end

  it "postpones the session expiry every request" do
    freeze_time do
      user = create(:user)
      session = sign_in(user)
      initial_expiry = user.session_validity_preference.seconds.from_now

      expect(initial_expiry).to eq(3.days.from_now)

      get(:index)
      expect(response).to have_http_status(:ok)
      expect(session.reload.expiration_at).to eq(initial_expiry)

      # If we make a request 2 minutes after the initial request, the expiry
      # should not have changed
      travel(2.minutes)
      get(:index)
      expect(response).to have_http_status(:ok)
      expect(session.reload.expiration_at).to eq(initial_expiry)

      # If we make a request more than 5 minutes after the initial request, the
      # expiry should be updated
      travel(3.minutes + 1.second)
      updated_expiry = user.session_validity_preference.seconds.from_now
      get(:index)
      expect(response).to have_http_status(:ok)
      expect(session.reload.expiration_at).to eq(updated_expiry)

      # If we make a request after the expiry time we should be redirected to
      # the login page
      travel_to(updated_expiry + 1.second)
      get(:index)
      expect(response).to redirect_to(auth_users_path(require_reload: true, return_to: request.original_url))
    end
  end

  it "caps the maximum session length to 3 weeks" do
    freeze_time do
      user = create(:user, session_validity_preference: SessionsHelper::SESSION_DURATION_OPTIONS.fetch("2 weeks"))
      session = sign_in(user)
      max_expiry = User::Session::MAX_SESSION_DURATION.from_now

      travel(2.weeks - 1.day)
      get(:index)
      expect(response).to have_http_status(:ok)
      expect(session.reload.expiration_at).to eq(max_expiry)
    end
  end
end
