# frozen_string_literal: true

require "rails_helper"

RSpec.describe User::Session::ClearOldUserSessionsJob do
  it "clears the IP address and user agent of expired sessions older than 18 months" do
    old = create(:user_session, created_at: 18.months.ago - 1.day, expiration_at: 1.year.ago, ip: "127.0.0.1", user_agent: "fake firefox")
    recent = create(:user_session, created_at: 18.months.ago + 1.day, expiration_at: 1.year.ago, ip: "127.0.0.1", user_agent: "fake firefox")

    described_class.perform_now

    expect(old.reload).to have_attributes(ip: nil, user_agent: nil)
    expect(recent.reload).to have_attributes(ip: "127.0.0.1", user_agent: "fake firefox")
  end

  it "keeps the metadata of an old session that has not expired yet" do
    live = create(:user_session, created_at: 2.years.ago, expiration_at: 1.day.from_now, ip: "127.0.0.1", user_agent: "fake firefox")

    described_class.perform_now

    expect(live.reload).to have_attributes(ip: "127.0.0.1", user_agent: "fake firefox")
  end
end
