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
      session = create_session(user, verified: true)
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

  it "caps ordinary session renewal at 3 weeks" do
    freeze_time do
      user = create(:user, session_validity_preference: SessionsHelper::SESSION_DURATION_OPTIONS.fetch("2 weeks"))
      session = create_session(user, verified: true)
      max_expiry = User::Session::MAX_SESSION_DURATION.from_now

      travel(2.weeks - 1.day)
      get(:index)
      expect(response).to have_http_status(:ok)
      expect(session.reload.expiration_at).to eq(max_expiry)
    end
  end

  it "extends active sessions an hour at a time for at most a day beyond the limit" do
    freeze_time do
      user = create(:user, session_validity_preference: 2.weeks.to_i)
      session = controller.create_session(user:, verified: true)
      max_expiry = 3.weeks.from_now

      travel(13.days)
      get(:index)
      expect(session.reload.expiration_at).to eq(max_expiry)

      travel_to(max_expiry - 30.minutes)
      get(:index)
      expect(response).to have_http_status(:ok)
      expect(session.reload.expiration_at).to eq(max_expiry + 30.minutes)

      24.times do
        travel(1.hour - 1.minute)
        get(:index)
        expect(response).to have_http_status(:ok)
        expect(session.reload.expiration_at).to eq([1.hour.from_now, max_expiry + 24.hours].min)
      end

      travel_to(max_expiry + 24.hours)
      get(:index)
      expect(response).to redirect_to(auth_users_path(require_reload: true, return_to: request.original_url))
    end
  end

  it "does not extend the user's inactivity preference during the grace period" do
    freeze_time do
      user = create(:user, session_validity_preference: 15.minutes.to_i)
      session = create_session(user, verified: true)
      session.update_columns(created_at: 3.weeks.ago)

      get(:index)
      expect(response).to have_http_status(:ok)
      expect(session.reload.expiration_at).to eq(15.minutes.from_now)

      travel(15.minutes)
      get(:index)
      expect(response).to redirect_to(auth_users_path(require_reload: true, return_to: request.original_url))
    end
  end
end
