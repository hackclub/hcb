# frozen_string_literal: true

require "rails_helper"

RSpec.describe Login::Attempt::ClearOldAttemptsJob do
  it "clears the IP address and user agent of attempts older than 18 months" do
    old = create(:login_attempt, created_at: 18.months.ago - 1.day)
    recent = create(:login_attempt, created_at: 18.months.ago + 1.day)

    described_class.perform_now

    expect(old.reload).to have_attributes(ip_address: nil, user_agent: nil, status: "failed")
    expect(recent.reload.ip_address.to_s).to eq("127.0.0.1")
    expect(recent.user_agent).to eq("fake firefox")
  end

  it "clears an old attempt that only has a user agent left" do
    old = create(:login_attempt, created_at: 2.years.ago, ip_address: nil)

    described_class.perform_now

    expect(old.reload.user_agent).to be_nil
  end
end
