# frozen_string_literal: true

require "rails_helper"

RSpec.describe "CardLocking.time_remaining_in_words" do
  let(:now) { Time.zone.parse("2026-10-10 12:00:00") }

  def words(due_at)
    CardLocking.time_remaining_in_words(due_at, now:)
  end

  it "counts down in days beyond the warning lead time" do
    expect(words(now + 3.days)).to eq("3 days")
    expect(words(now + 7.days)).to eq("7 days")
  end

  it "counts down in hours inside the warning lead time" do
    expect(words(now + 11.hours)).to eq("11 hours")
    expect(words(now + 47.hours)).to eq("47 hours")
  end

  it "counts down in minutes under an hour" do
    expect(words(now + 45.minutes)).to eq("45 minutes")
  end

  it "singularizes the unit" do
    expect(words(now + 1.hour)).to eq("1 hour")
    expect(words(now + 2.days + 1.hour)).to eq("2 days")
    expect(words(now + 61.seconds)).to eq("1 minute")
  end

  # A cardholder must never be told they have more runway than they do, so every
  # boundary rounds toward the deadline.
  it "always rounds down" do
    expect(words(now + 11.hours + 59.minutes)).to eq("11 hours")
    expect(words(now + 3.days + 23.hours)).to eq("3 days")
  end

  it "switches from hours to days exactly at the warning lead time" do
    expect(words(now + CardLocking::WARNING_LEAD_TIME - 1.second)).to eq("47 hours")
    expect(words(now + CardLocking::WARNING_LEAD_TIME)).to eq("2 days")
  end

  # Under a minute is still ahead of the deadline; "0 minutes" would read as past.
  it "floors at one minute rather than zero" do
    expect(words(now + 30.seconds)).to eq("1 minute")
  end

  it "is nil once the deadline has passed, so callers say something else" do
    expect(words(now)).to be_nil
    expect(words(now - 1.second)).to be_nil
    expect(words(now - 3.days)).to be_nil
  end

  it "is nil without a deadline" do
    expect(words(nil)).to be_nil
  end
end
