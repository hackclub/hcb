# frozen_string_literal: true

require "rails_helper"

RSpec.describe "POST /users/:id/unimpersonate", type: :request do
  it "is reachable when the impersonation session mirrors an unverified target" do
    admin = create(:user, :make_admin)
    shadow = create(:user, verified: false, creation_method: :first_robotics_form)

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

    post "/users/#{shadow.id}/unimpersonate"

    expect(response.location.to_s).not_to include("/users/auth"),
                                          "Expected /users/<id>/unimpersonate to reach the action and redirect " \
                                          "to root_path. Got #{response.status} #{response.location.inspect}, " \
                                          "which means `signed_in_user` is still gating the unverified-target " \
                                          "impersonation session and the admin is locked out."
    expect(response).to redirect_to(root_path)
  end
end
