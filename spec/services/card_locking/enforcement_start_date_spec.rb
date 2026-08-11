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

  it "is 2026-07-17 for a cardholder in the 07_17 stage" do
    Flipper.enable(:card_locking_enabled_on_07_17_2026, user)

    expect(CardLocking.enforcement_start_date(user)).to eq(Date.new(2026, 7, 17))
  end

  it "is 2026-08-11 for a cardholder in the 08_11 stage" do
    Flipper.enable(:card_locking_enabled_on_08_11_2026, user)

    expect(CardLocking.enforcement_start_date(user)).to eq(Date.new(2026, 8, 11))
  end

  # Switching a later stage on for everyone hands its flag to cardholders who are
  # already enforced under an earlier one. They must keep the earlier date, or
  # their existing deadlines and locks silently reset.
  it "keeps the earlier date for a cardholder who gains a later stage's flag" do
    Flipper.enable(:card_locking_enabled_on_07_17_2026, user)
    Flipper.enable(:card_locking_enabled_on_08_11_2026, user)

    expect(CardLocking.enforcement_start_date(user)).to eq(Date.new(2026, 7, 17))
  end

  # The global floor bounds candidate discovery for every cardholder at once.
  # Moving it forward drops already-enforced charges out of card_locking_candidates,
  # so it stays pinned to the first stage HCB ever enforced.
  it "floors enforcement at 2026-07-17 for every cardholder" do
    expect(CardLocking::ENFORCEMENT_START_DATE).to eq(Date.new(2026, 7, 17))
  end
end
