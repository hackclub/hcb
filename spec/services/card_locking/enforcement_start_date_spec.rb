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

  it "is 2026-07-14 for a cardholder in the first stage" do
    Flipper.enable(:card_locking_enabled_on_07_17_2026, user)

    expect(CardLocking.enforcement_start_date(user)).to eq(Date.new(2026, 7, 17))
  end

  it "is 2026-07-28 for a cardholder in the second stage" do
    Flipper.enable(:card_locking_enabled_on_07_28_2026, user)

    expect(CardLocking.enforcement_start_date(user)).to eq(Date.new(2026, 7, 28))
  end

  it "is 2026-08-11 for a cardholder in the general rollout stage" do
    Flipper.enable(:card_locking_enabled_on_08_11_2026, user)

    expect(CardLocking.enforcement_start_date(user)).to eq(Date.new(2026, 8, 11))
  end

  it "uses the earliest stage the cardholder is in" do
    Flipper.enable(:card_locking_enabled_on_07_17_2026, user)
    Flipper.enable(:card_locking_enabled_on_07_28_2026, user)

    expect(CardLocking.enforcement_start_date(user)).to eq(Date.new(2026, 7, 17))
  end

  # The general rollout switches the 08/11 stage on for everyone, so a pilot
  # cardholder ends up holding both flags. Earliest-wins is what keeps their
  # enforcement date, and therefore their existing deadlines and locks, unmoved.
  it "keeps a pilot cardholder on their original date once the general stage is on" do
    Flipper.enable(:card_locking_enabled_on_07_17_2026, user)
    Flipper.enable(:card_locking_enabled_on_08_11_2026, user)

    expect(CardLocking.enforcement_start_date(user)).to eq(Date.new(2026, 7, 17))
  end

  it "does not let the global floor drift past the earliest stage" do
    expect(CardLocking::ENFORCEMENT_START_DATE).to eq(CardLocking::ENFORCEMENT_STAGES.values.min)
  end
end
