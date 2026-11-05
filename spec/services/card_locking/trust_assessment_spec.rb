# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardLocking::TrustAssessment do
  def trusted?(on_time:, considered:, recent:)
    described_class.new(
      on_time_count: on_time,
      considered_count: considered,
      most_recent_on_time: recent
    ).trusted?
  end

  it "case 1: 0 considered → false" do
    expect(trusted?(on_time: 0, considered: 0, recent: true)).to be false
  end

  it "case 2: 1/1 on time, recent true → true" do
    expect(trusted?(on_time: 1, considered: 1, recent: true)).to be true
  end

  it "case 3: 7/10 recent true → false (below 0.8)" do
    expect(trusted?(on_time: 7, considered: 10, recent: true)).to be false
  end

  it "case 4: 8/10 recent true → true (exactly 0.8 boundary)" do
    expect(trusted?(on_time: 8, considered: 10, recent: true)).to be true
  end

  it "case 5: 9/10 recent false → false (recency clause)" do
    expect(trusted?(on_time: 9, considered: 10, recent: false)).to be false
  end

  it "case 6: recent: nil (distinct from false), 9/10 → false" do
    expect(trusted?(on_time: 9, considered: 10, recent: nil)).to be false
  end

  it "case 7: 0/5 considered, recent false → false (considered but zero on-time; distinct from 0/0)" do
    expect(trusted?(on_time: 0, considered: 5, recent: false)).to be false
  end
end
