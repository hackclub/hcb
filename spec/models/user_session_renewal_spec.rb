# frozen_string_literal: true

require "rails_helper"

RSpec.describe "User::Session timestamp renewal for zombie sessions", type: :model do
  it "revokes an unverified session whose underlying user is verified" do
    user = create(:user, verified: true)

    zombie = User::Session.new(
      user: user,
      verified: false,
      session_token: SecureRandom.urlsafe_base64,
      expiration_at: 1.minute.from_now,
      last_seen_at: 1.hour.ago,
    )
    zombie.save!(validate: false)

    zombie.update_session_timestamps
    zombie.reload

    expect(zombie).to be_expired
    expect(zombie.signed_out_at).to be_present
  end
end
