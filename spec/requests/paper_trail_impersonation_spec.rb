# frozen_string_literal: true

require "rails_helper"

RSpec.describe "PaperTrail impersonation tracking", type: :request, versioning: true do
  let(:admin) { create(:user, :make_admin) }
  let(:user) { create(:user, full_name: "Original Name") }

  def sign_in_with(session)
    allow_any_instance_of(SessionsHelper)
      .to receive(:find_current_session)
      .and_return(session)
  end

  it "records the impersonator on versions created while impersonating" do
    sign_in_with(create(:user_session, user:, impersonated_by: admin, expiration_at: 1.hour.from_now))

    patch "/users/#{user.id}", params: { user: { full_name: "Changed Name" } }

    version = user.versions.last
    expect(version.whodunnit).to eq(user.id.to_s)
    expect(version.impersonated_by_id).to eq(admin.id)
  end

  it "leaves the impersonator blank on versions created without impersonation" do
    sign_in_with(create(:user_session, user:, expiration_at: 1.hour.from_now))

    patch "/users/#{user.id}", params: { user: { full_name: "Changed Name" } }

    version = user.versions.last
    expect(version.whodunnit).to eq(user.id.to_s)
    expect(version.impersonated_by_id).to be_nil
  end
end
