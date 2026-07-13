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
end
