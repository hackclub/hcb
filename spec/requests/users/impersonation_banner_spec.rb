# frozen_string_literal: true

require "rails_helper"

RSpec.describe "impersonation banner", type: :request do
  let(:admin) { create(:user, :make_admin) }
  let(:shadow) { create(:user, verified: false) }

  before do
    impersonation_session = create(
      :user_session,
      user: shadow,
      verified: false,
      impersonated_by: admin,
      expiration_at: 1.hour.from_now,
    )

    allow_any_instance_of(SessionsHelper)
      .to receive(:find_current_session)
      .and_return(impersonation_session)
  end

  # Impersonation sessions mirror their target's `verified` flag, so
  # `current_user` is nil while impersonating an unverified account. The banner
  # used to build the exit link from `current_user&.id`, which blew up with
  # "No route matches ... id: nil" on every page it rendered on.
  it "renders the exit link on the docs layout" do
    get "/branding"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(unimpersonate_user_path(shadow))
  end

  it "renders the exit link on the application layout" do
    get "/applications/new"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(unimpersonate_user_path(shadow))
  end
end
