# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReceiptsHelper, type: :helper do
  let(:now) { Time.zone.parse("2026-08-06 14:00:00") }

  def charge(due_at, settled: true)
    instance_double(HcbCode, receipt_due_at: due_at, canonical_transactions: settled ? [instance_double(CanonicalTransaction)] : [])
  end

  describe "#receipt_due_group" do
    it "collapses everything already past its deadline into one :overdue bucket" do
      expect(helper.receipt_due_group(charge(now - 7.days), now:)).to eq(:overdue)
      expect(helper.receipt_due_group(charge(now - 1.second), now:)).to eq(:overdue)
    end

    it "treats a deadline landing exactly on now as overdue" do
      expect(helper.receipt_due_group(charge(now), now:)).to eq(:overdue)
    end

    it "buckets future deadlines by the calendar day they fall due on" do
      expect(helper.receipt_due_group(charge(now + 1.hour), now:)).to eq(now.to_date)
      expect(helper.receipt_due_group(charge(now + 3.days), now:)).to eq((now + 3.days).to_date)
    end

    it "gives settled charges with no deadline their own bucket rather than inventing a date" do
      expect(helper.receipt_due_group(charge(nil), now:)).to eq(:none)
    end

    it "separates charges that haven't settled yet from the undated long tail" do
      expect(helper.receipt_due_group(charge(nil, settled: false), now:)).to eq(:pending)
    end

    it "buckets two charges due the same day together even at different times" do
      morning = helper.receipt_due_group(charge(now + 1.day), now:)
      evening = helper.receipt_due_group(charge(now + 1.day + 6.hours), now:)

      expect(morning).to eq(evening)
    end
  end

  describe "#receipt_due_group_label" do
    it "names the buckets that aren't dates" do
      expect(helper.receipt_due_group_label(:overdue, now:)).to eq("Overdue")
      expect(helper.receipt_due_group_label(:pending, now:)).to eq("Pending transactions")
      expect(helper.receipt_due_group_label(:none, now:)).to eq("Older receipts")
    end

    it "uses relative wording for the next couple of days" do
      expect(helper.receipt_due_group_label(now.to_date, now:)).to eq("Due today")
      expect(helper.receipt_due_group_label(now.to_date + 1, now:)).to eq("Due tomorrow")
    end

    it "uses the weekday inside the coming week, then falls back to a date" do
      expect(helper.receipt_due_group_label(now.to_date + 3, now:)).to eq("Due Sunday")
      expect(helper.receipt_due_group_label(now.to_date + 6, now:)).to eq("Due Wednesday")
      # Day 7 is the same weekday as today, so a weekday name would be ambiguous.
      expect(helper.receipt_due_group_label(now.to_date + 7, now:)).to eq("Due Aug 13")
    end
  end

  describe "#receipt_due_group_urgency" do
    it "ranks overdue, then the next 48 hours, then everything else" do
      expect(helper.receipt_due_group_urgency(:overdue, now:)).to eq(:overdue)
      expect(helper.receipt_due_group_urgency(now.to_date, now:)).to eq(:soon)
      expect(helper.receipt_due_group_urgency(now.to_date + 1, now:)).to eq(:soon)
      expect(helper.receipt_due_group_urgency(now.to_date + 2, now:)).to eq(:later)
      expect(helper.receipt_due_group_urgency(:pending, now:)).to eq(:pending)
      expect(helper.receipt_due_group_urgency(:none, now:)).to eq(:none)
    end
  end

  describe "#receipt_due_group_style" do
    it "only flags overdue groups in red" do
      expect(helper.receipt_due_group_style(:overdue, now:)).to include(icon_class: "error", badge_class: "bg-error")
      expect(helper.receipt_due_group_style(now.to_date, now:)).to include(icon_class: "muted", badge_class: "bg-warning")
      expect(helper.receipt_due_group_style(now.to_date + 5, now:)).to include(icon_class: "muted", badge_class: "bg-muted")
      expect(helper.receipt_due_group_style(:pending, now:)).to include(icon_class: "muted", badge_class: "bg-muted")
      expect(helper.receipt_due_group_style(:none, now:)).to include(icon_class: "muted", badge_class: "bg-muted")
    end

    it "names icons that actually exist" do
      groups = [:overdue, :pending, :none, now.to_date, now.to_date + 5]

      groups.each do |group|
        icon = helper.receipt_due_group_style(group, now:)[:icon]
        expect(Rails.root.join("app/assets/images/icons/#{icon}.svg")).to exist, "missing icon #{icon}.svg"
      end
    end
  end
end
