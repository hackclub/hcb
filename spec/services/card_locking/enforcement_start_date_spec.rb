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

  # The floor in ENFORCEMENT_START_DATE excludes every charge the earlier stages
  # could have covered, so all stages carry it and list order cannot matter. This
  # guards that invariant; the per-stage examples below pin the date itself.
  it "carries ENFORCEMENT_START_DATE on every stage" do
    expect(CardLocking::ENFORCEMENT_STAGES.map(&:last).uniq).to eq([CardLocking::ENFORCEMENT_START_DATE])
  end

  it "is 2026-08-11 for a cardholder in the current stage" do
    Flipper.enable(:card_locking_enabled_on_08_11_2026, user)

    expect(CardLocking.enforcement_start_date(user)).to eq(Date.new(2026, 8, 11))
  end

  it "is 2026-08-11 for a cardholder still on the 07_28 stage flag" do
    Flipper.enable(:card_locking_enabled_on_07_28_2026, user)

    expect(CardLocking.enforcement_start_date(user)).to eq(Date.new(2026, 8, 11))
  end

  it "is 2026-08-11 for a cardholder still on the 07_17 stage flag" do
    Flipper.enable(:card_locking_enabled_on_07_17_2026, user)

    expect(CardLocking.enforcement_start_date(user)).to eq(Date.new(2026, 8, 11))
  end

  it "resolves to the one enforcement date for a cardholder in several stages" do
    CardLocking::ENFORCEMENT_STAGES.map(&:first).each { |flag| Flipper.enable(flag, user) }

    expect(CardLocking.enforcement_start_date(user)).to eq(Date.new(2026, 8, 11))
  end
end
