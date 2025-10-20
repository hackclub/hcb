# frozen_string_literal: true

require "rails_helper"

RSpec.describe Event::StatementOfActivity do
  describe "#start_date" do
    it "parses the param value if one is provided" do
      event = create(:event)
      instance = described_class.new(event, start_date_param: "2025-01-01")

      expect(instance.start_date).to eq(Date.new(2025, 1, 1))
    end

    it "falls back to the event activation date" do
      event = create(:event, activated_at: Time.new(2025, 1, 1))
      instance = described_class.new(event)

      expect(instance.start_date).to eq(Date.new(2025, 1, 1))
    end

    it "falls back to the event creation date" do
      event = create(:event, created_at: Time.new(2025, 1, 1))
      instance = described_class.new(event)

      expect(instance.start_date).to eq(Date.new(2025, 1, 1))
    end

    it "picks the oldest creation date when dealing with a group" do
      group = create(:event_group)

      event1 = create(:event, created_at: Time.new(2025, 1, 1))
      group.memberships.create!(event: event1)

      event2 = create(:event, created_at: Time.new(2024, 1, 1))
      group.memberships.create!(event: event2)

      instance = described_class.new(group)

      expect(instance.start_date).to eq(Date.new(2024, 1, 1))
    end

    it "picks the oldest creation date when including descendants" do
      event1 = create(:event, created_at: Time.new(2025, 1, 1))
      _event2 = create(:event, created_at: Time.new(2024, 1, 1), parent: event1)

      instance = described_class.new(event1, include_descendants: true)

      expect(instance.start_date).to eq(Date.new(2024, 1, 1))
    end

    it "falls back to the current date" do
      freeze_time do
        travel_to(Time.new(2025, 1, 1))

        group = create(:event_group)

        instance = described_class.new(group)

        expect(instance.start_date).to eq(Date.new(2025, 1, 1))
      end
    end
  end

  describe "#end_date" do
    it "parses the param value if one is provided" do
      event = create(:event)
      instance = described_class.new(event, end_date_param: "2025-01-01")

      expect(instance.end_date).to eq(Date.new(2025, 1, 1))
    end

    it "falls back to the current date" do
      freeze_time do
        travel_to(Time.new(2025, 1, 1))
        event = create(:event)
        instance = described_class.new(event)

        expect(instance.start_date).to eq(Date.new(2025, 1, 1))
      end
    end
  end

  describe "#transactions_by_category" do
    it "returns a hash of transactions grouped by category with unknowns last" do
      event = create(:event)

      rent = create(:canonical_transaction, category_slug: "rent")
      create(:canonical_event_mapping, event:, canonical_transaction: rent)

      unknown = create(:canonical_transaction)
      create(:canonical_event_mapping, event:, canonical_transaction: unknown)

      instance = described_class.new(event, start_date_param: "1970-01-01")
      result = instance.transactions_by_category

      expect(result).to be_a(Hash)
      expect(result.keys).to eq([rent.category, nil])
      expect(result[rent.category]).to eq([rent])
      expect(result[nil]).to eq([unknown])
    end

    it "takes into account all transactions within a group" do
      group = create(:event_group)

      event1 = create(:event)
      group.memberships.create!(event: event1)
      event1_rent = create(:canonical_transaction, category_slug: "rent")
      create(:canonical_event_mapping, event: event1, canonical_transaction: event1_rent)

      event2 = create(:event)
      group.memberships.create!(event: event2)
      event2_unknown = create(:canonical_transaction)
      create(:canonical_event_mapping, event: event2, canonical_transaction: event2_unknown)

      instance = described_class.new(group, start_date_param: "1970-01-01")
      result = instance.transactions_by_category

      expect(result).to be_a(Hash)
      expect(result.keys).to eq([event1_rent.category, nil])
      expect(result[event1_rent.category]).to eq([event1_rent])
      expect(result[nil]).to eq([event2_unknown])
    end

    it "includes transactions from descendants when configured" do
      event1 = create(:event)
      event1_rent = create(:canonical_transaction, category_slug: "rent")
      create(:canonical_event_mapping, event: event1, canonical_transaction: event1_rent)

      event2 = create(:event, parent: event1)
      event2_unknown = create(:canonical_transaction)
      create(:canonical_event_mapping, event: event2, canonical_transaction: event2_unknown)

      instance = described_class.new(event1, start_date_param: "1970-01-01", include_descendants: true)
      result = instance.transactions_by_category

      expect(result).to be_a(Hash)
      expect(result.keys).to eq([event1_rent.category, nil])
      expect(result[event1_rent.category]).to eq([event1_rent])
      expect(result[nil]).to eq([event2_unknown])
    end

    it "honors the start date and end date" do
      event = create(:event, created_at: Time.new(2024, 1, 1))

      transactions = 1.upto(3).map do |day|
        canonical_transaction = create(
          :canonical_transaction,
          category_slug: "rent",
          date: Date.new(2025, 1, day)
        )
        create( :canonical_event_mapping, event:, canonical_transaction: )

        canonical_transaction
      end

      rent = TransactionCategory.find_by!(slug: "rent")

      result_with_start = described_class.new(event, start_date_param: "2025-01-02").transactions_by_category
      expect(result_with_start.keys).to eq([rent])
      expect(result_with_start[rent]).to contain_exactly(transactions[1], transactions[2])

      result_with_end = described_class.new(event, end_date_param: "2025-01-02").transactions_by_category
      expect(result_with_end.keys).to eq([rent])
      expect(result_with_end[rent]).to contain_exactly(transactions[0], transactions[1])
    end
  end

  describe "#category_totals, #net_asset_change, #total_revenue, #total_expense" do
    specify "single event" do
      event = create(:event)

      2.times do
        rent = create(:canonical_transaction, category_slug: "rent", amount_cents: 12_34)
        create(:canonical_event_mapping, event:, canonical_transaction: rent)
      end

      2.times do
        unknown = create(:canonical_transaction, amount_cents: -56_78)
        create(:canonical_event_mapping, event:, canonical_transaction: unknown)
      end

      instance = described_class.new(event, start_date_param: "1970-01-01")

      category_totals = instance.category_totals
      expect(category_totals).to be_a(Hash)
      expect(category_totals.keys).to eq(["rent", nil])
      expect(category_totals["rent"]).to eq(24_68)
      expect(category_totals[nil]).to eq(-113_56)

      expect(instance.net_asset_change).to eq(-88_88)
      expect(instance.total_revenue).to eq(24_68)
      expect(instance.total_expense).to eq(-113_56)
    end

    specify "group" do
      group = create(:event_group)
      event1, event2 = create_list(:event, 2)

      [event1, event2].each do |event|
        group.memberships.create!(event: event)

        rent = create(:canonical_transaction, category_slug: "rent", amount_cents: 12_34)
        create(:canonical_event_mapping, event:, canonical_transaction: rent)

        unknown = create(:canonical_transaction, amount_cents: -56_78)
        create(:canonical_event_mapping, event:, canonical_transaction: unknown)
      end

      instance = described_class.new(group, start_date_param: "1970-01-01")

      category_totals = instance.category_totals
      expect(category_totals).to be_a(Hash)
      expect(category_totals.keys).to eq(["rent", nil])
      expect(category_totals["rent"]).to eq(24_68)
      expect(category_totals[nil]).to eq(-113_56)

      expect(instance.net_asset_change).to eq(-88_88)
      expect(instance.total_revenue).to eq(24_68)
      expect(instance.total_expense).to eq(-113_56)
    end

    specify "with descendants" do
      event1, event2 = create_list(:event, 2)
      event2.update!(parent: event1)

      [event1, event2].each do |event|
        rent = create(:canonical_transaction, category_slug: "rent", amount_cents: 12_34)
        create(:canonical_event_mapping, event:, canonical_transaction: rent)

        unknown = create(:canonical_transaction, amount_cents: -56_78)
        create(:canonical_event_mapping, event:, canonical_transaction: unknown)
      end

      instance = described_class.new(event1, start_date_param: "1970-01-01", include_descendants: true)

      category_totals = instance.category_totals
      expect(category_totals).to be_a(Hash)
      expect(category_totals.keys).to eq(["rent", nil])
      expect(category_totals["rent"]).to eq(24_68)
      expect(category_totals[nil]).to eq(-113_56)

      expect(instance.net_asset_change).to eq(-88_88)
      expect(instance.total_revenue).to eq(24_68)
      expect(instance.total_expense).to eq(-113_56)
    end
  end
end
