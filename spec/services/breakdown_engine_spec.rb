# frozen_string_literal: true

require "rails_helper"

RSpec.describe BreakdownEngine do
  describe ".date_range" do
    it "covers the whole calendar year for a year timeframe" do
      start_date, end_date = described_class.date_range("2025")

      expect(start_date).to eq(Time.zone.local(2025, 1, 1))
      expect(end_date).to eq(Time.zone.local(2025, 12, 31).end_of_day)
    end

    it "falls back to all time for anything that isn't a known timeframe or a four digit year" do
      ["Past decade", "20255", "2025\n", "2025 OR 1=1", "", nil].each do |timeframe|
        expect(described_class.date_range(timeframe).first).to be_nil
      end
    end
  end

  describe ".timeframes_for" do
    let(:event) { create(:event, created_at: 2.months.ago) }

    before { Rails.cache.clear }

    def add_items(count, ledger: event.ledger, datetime: Time.zone.local(2025, 6, 1), **columns)
      create_list(:ledger_item, count).each do |item|
        Ledger::Mapping.create!(ledger:, ledger_item: item, on_primary_ledger: true)
        item.update_columns(datetime:, ct_count: 1, **columns)
      end
    end

    it "only offers rolling timeframes the organization is old enough for" do
      expect(described_class.timeframes_for(event)).to eq(["All time", "Past month"])
    end

    it "offers a year once it has ten transactions" do
      add_items(9)
      expect(described_class.timeframes_for(event)).not_to include("2025")

      Rails.cache.clear
      add_items(1)
      expect(described_class.timeframes_for(event)).to include("2025")
    end

    it "doesn't count another organization's transactions or ones that haven't moved money" do
      add_items(9)
      add_items(1, ct_count: 0, cpt_count: 0)
      add_items(5, ledger: create(:event).ledger)

      expect(described_class.timeframes_for(event)).not_to include("2025")
    end
  end
end
