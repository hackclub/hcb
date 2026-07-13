# frozen_string_literal: true

require "rails_helper"

RSpec.describe Payroll::Position, type: :model do
  describe "#status" do
    {
      "under_review" => :onboarding,
      "onboarding"   => :onboarding,
      "onboarded"    => :active,
      "expired"      => :completed,
      "terminated"   => :completed,
      "rejected"     => :completed,
    }.each do |aasm_state, expected|
      it "maps #{aasm_state} to #{expected}" do
        position = described_class.new(aasm_state:)
        expect(position.status).to eq(expected)
      end
    end
  end

  describe "#period_label" do
    it "returns nil when there is no start date" do
      expect(described_class.new(start_date: nil).period_label).to be_nil
    end

    it "shows a single month when there is no end date" do
      position = described_class.new(start_date: Date.new(2026, 4, 1))
      expect(position.period_label).to eq("Apr 2026")
    end

    it "collapses to a single month when start and end fall in the same month" do
      position = described_class.new(start_date: Date.new(2026, 4, 1), end_date: Date.new(2026, 4, 28))
      expect(position.period_label).to eq("Apr 2026")
    end

    it "shows a range within the same year" do
      position = described_class.new(start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 6, 30))
      expect(position.period_label).to eq("Jan–Jun 2026")
    end

    it "spans years when start and end fall in different years" do
      position = described_class.new(start_date: Date.new(2025, 12, 1), end_date: Date.new(2026, 2, 28))
      expect(position.period_label).to eq("Dec 2025–Feb 2026")
    end
  end

  describe "date validations" do
    let(:payee) { create(:payee) }

    def build_position(**attrs)
      build(:payroll_position, payee:, **attrs)
    end

    it "requires the end date to be after the start date" do
      position = build_position(start_date: Date.current, end_date: Date.current)
      expect(position).to be_invalid
      expect(position.errors[:end_date]).to include("must be after the start date")
    end

    it "rejects a start date more than the max lead time in the future" do
      position = build_position(
        start_date: (Payroll::Position::MAX_START_LEAD_TIME.from_now + 1.day).to_date,
        end_date: (Payroll::Position::MAX_START_LEAD_TIME.from_now + 2.days).to_date
      )
      expect(position).to be_invalid
      expect(position.errors[:start_date]).to include("cannot be more than 6 months in the future")
    end

    it "rejects a duration longer than the max" do
      start_date = Date.current
      position = build_position(start_date:, end_date: start_date + Payroll::Position::MAX_DURATION + 1.day)
      expect(position).to be_invalid
      expect(position.errors[:end_date]).to include("cannot be more than 1 year after the start date")
    end

    it "accepts a valid window" do
      start_date = Date.current
      position = build_position(start_date:, end_date: start_date + 3.months)
      expect(position).to be_valid
    end
  end
end
