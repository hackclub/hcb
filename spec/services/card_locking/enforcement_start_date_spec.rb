# frozen_string_literal: true

require "rails_helper"

RSpec.describe "CardLocking.enforcement_start_date" do
  let(:user) { create(:user) }

  it "is nil when the cardholder is in no rollout stage" do
    expect(CardLocking.enforcement_start_date(user)).to be_nil
  end

  it "is nil for a nil user" do
    expect(CardLocking.enforcement_start_date(nil)).to be_nil
  end

  it "is 2026-08-11 for a cardholder in the first stage" do
    Flipper.enable(:card_locking_enabled_on_08_11_2026, user)

    expect(CardLocking.enforcement_start_date(user)).to eq(Date.new(2026, 8, 11))
  end

  it "is 2026-07-28 for a cardholder in the second stage" do
    Flipper.enable(:card_locking_enabled_on_07_28_2026, user)

    expect(CardLocking.enforcement_start_date(user)).to eq(Date.new(2026, 7, 28))
  end

  # The 08_11 stage is listed first but dated after the (now inert) 07_28 stage, so
  # first-match-by-list-order no longer coincides with earliest-date.
  it "uses the first stage in list order the cardholder is in" do
    Flipper.enable(:card_locking_enabled_on_08_11_2026, user)
    Flipper.enable(:card_locking_enabled_on_07_28_2026, user)

    expect(CardLocking.enforcement_start_date(user)).to eq(Date.new(2026, 8, 11))
  end
end
