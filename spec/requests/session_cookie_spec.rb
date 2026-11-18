# frozen_string_literal: true

require "rails_helper"

# Request specs sign in by sending a real encrypted `session_token` cookie (see
# RequestSessionSupport). These examples check that path end to end, so specs
# that only assert something *didn't* happen can't pass because sign-in
# silently failed.
RSpec.describe "Session cookie", type: :request do
  let(:user) { create(:user) }

  it "signs in with an unexpired session" do
    sign_in_with(create(:user_session, user:, expiration_at: 1.hour.from_now))

    get my_settings_path

    expect(response).to have_http_status(:ok)
  end

  it "treats an expired session as signed out" do
    sign_in_with(create(:user_session, user:, expiration_at: 1.minute.ago))

    get my_settings_path

    expect(response).to have_http_status(:redirect)
    expect(response.location).to start_with(auth_users_url)
  end
end
