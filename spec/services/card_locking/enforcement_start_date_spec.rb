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

  # Switching a later stage on for everyone hands its flag to already-enforced
  # cardholders; keeping the earlier date is what stops their locks resetting.
  it "keeps the earlier date for a cardholder who gains a later stage's flag" do
    Flipper.enable(:card_locking_enabled_on_07_17_2026, user)
    Flipper.enable(:card_locking_enabled_on_08_11_2026, user)

    expect(CardLocking.enforcement_start_date(user)).to eq(Date.new(2026, 7, 17))
  end

  # A literal, not ENFORCEMENT_STAGES.values.min, which is what the constant is
  # derived from and would assert nothing. Catches a repointed or deleted earliest
  # stage; the consequence is covered in spec/integration/card_locking_rollout_day_spec.rb.
  it "pins the global enforcement floor to 2026-07-17" do
    expect(CardLocking::ENFORCEMENT_START_DATE).to eq(Date.new(2026, 7, 17))
  end
end
