# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardLocking::Deadline do
  let(:now) { Time.zone.parse("2026-08-01 12:00:00") }
  let(:settled_at) { now - 1.day }

  def compute(**overrides)
    described_class.new(
      settled_at:,
      trusted: false,
      last_settled_charge_at: settled_at,
      current_due_at: nil,
      now:,
      **overrides
    ).compute
  end

  it "case 1: untrusted → settled_at + 7.days" do
    expect(compute).to eq(settled_at + 7.days)
  end

  it "case 2: untrusted ignores slide even with last_settled_charge_at: now" do
    expect(compute(last_settled_charge_at: now)).to eq(settled_at + 7.days)
  end

  it "case 3: trusted slide → last + 7.days where last = settled_at + 3.days" do
    last_charge = settled_at + 3.days
    expect(compute(trusted: true, last_settled_charge_at: last_charge)).to eq(last_charge + 7.days)
  end

  it "case 4: trusted never below base: last = settled_at - 2.days → settled_at + 7.days" do
    last_charge = settled_at - 2.days
    expect(compute(trusted: true, last_settled_charge_at: last_charge)).to eq(settled_at + 7.days)
  end

  it "case 5: trusted never above cap: last = settled_at + 30.days → settled_at + 14.days" do
    last_charge = settled_at + 30.days
    expect(compute(trusted: true, last_settled_charge_at: last_charge)).to eq(settled_at + 14.days)
  end

  it "case 6: EXACTLY at cap: last = settled_at + 7.days → settled_at + 14.days" do
    last_charge = settled_at + 7.days
    expect(compute(trusted: true, last_settled_charge_at: last_charge)).to eq(settled_at + 14.days)
  end

  it "case 7: trusted with last_settled_charge_at: nil → base (settled_at + 7.days)" do
    expect(compute(trusted: true, last_settled_charge_at: nil)).to eq(settled_at + 7.days)
  end

  it "case 8: trusted with last_settled_charge_at == settled_at → settled_at + 7.days (single charge in isolation)" do
    expect(compute(trusted: true, last_settled_charge_at: settled_at)).to eq(settled_at + 7.days)
  end

  it "case 9: no due date set (current_due_at: nil) → fresh target" do
    expect(compute(current_due_at: nil)).to eq(settled_at + 7.days)
  end

  it "case 10: lengthening allowed: current = settled_at + 7.days, trusted, last = settled_at + 5.days → last + 7.days" do
    current_due = settled_at + 7.days
    last_charge = settled_at + 5.days
    expect(compute(trusted: true, last_settled_charge_at: last_charge, current_due_at: current_due)).to eq(last_charge + 7.days)
  end

  it "case 11: shortening does not drop below now+72h: settled = now - 6.days, untrusted, current = now + 5.days → now + 72.hours" do
    settled = now - 6.days
    current_due = now + 5.days
    expect(compute(settled_at: settled, current_due_at: current_due)).to eq(now + 72.hours)
  end

  it "case 12: EXACTLY at floor: settled = now + 72.hours - 7.days, untrusted, current = now + 10.days → now + 72.hours" do
    settled = now + 72.hours - 7.days
    current_due = now + 10.days
    expect(compute(settled_at: settled, current_due_at: current_due)).to eq(now + 72.hours)
  end

  it "case 13: shorten only to target when target beyond floor: current = now + 10.days, settled = now - 1.day, untrusted → settled + 7.days" do
    settled = now - 1.day
    current_due = now + 10.days
    expect(compute(settled_at: settled, current_due_at: current_due)).to eq(settled + 7.days)
  end

  it "case 14: current_due_at == now exactly → returns current_due_at unchanged" do
    expect(compute(current_due_at: now)).to eq(now)
  end

  it "case 15: target == current_due_at exactly (lengthening branch equality): untrusted, current = settled_at + 7.days == base → settled_at + 7.days" do
    current_due = settled_at + 7.days
    expect(compute(current_due_at: current_due)).to eq(settled_at + 7.days)
  end

  it "case 16: first deadline whose target is already past → now + 72.hours" do
    expect(compute(settled_at: now - 30.days)).to eq(now + 72.hours)
  end

  it "case 17: first deadline inside the floor → now + 72.hours" do
    expect(compute(settled_at: now - 5.days)).to eq(now + 72.hours)
  end

  it "case 18: first deadline beyond the floor is untouched by it" do
    expect(compute(settled_at: now - 1.day)).to eq(now - 1.day + 7.days)
  end

  # A resolved charge's deadline is read by receipt_trusted? to decide whether the
  # receipt was on time. Flooring it forward would recast a late upload as on-time.
  it "case 19: a resolved charge's first deadline is not floored" do
    expect(compute(settled_at: now - 30.days, resolved: true)).to eq(now - 30.days + 7.days)
  end
end
