# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::RevokeLockedUsersApiAccessTask do
  let(:locked_user) { create(:user, locked_at: 1.day.ago) }
  let(:unlocked_user) { create(:user) }

  it "only collects locked users" do
    locked_user
    unlocked_user

    expect(described_class.collection).to contain_exactly(locked_user)
  end

  it "revokes a locked user's expired tokens that still hold a refresh token" do
    application = Doorkeeper::Application.create!(name: "Test App", redirect_uri: "https://example.com/callback")
    survivor = create(:api_token, user: locked_user, application:, use_refresh_token: true, expires_in: 1, created_at: 3.hours.ago)

    described_class.process(locked_user)

    expect(survivor.reload).to be_revoked
  end
end
