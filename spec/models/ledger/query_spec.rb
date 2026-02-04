# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledger::Query, type: :model do
  # Shared test dataset - created once and reused across all tests
  # Using a dedicated ledger for isolation from existing DB data
  let(:test_event) { create(:event) }
  let(:test_ledger) { test_event.ledger }

  # Dataset designed to cover all operator edge cases:
  # - Varying amounts: 0, 100, 150, 200, 300, 500 (plus duplicate 100)
  # - Varying memos: "zero item", "alpha payment", "alpha refund", "beta refund", "beta payment", "gamma payment", "delta payment"
  # - Varying dates: spread across Jan-Mar 2024
  # Note: memo is required by validation, so we can't test null on memo directly
  let(:item_a) { create_mapped_item(amount_cents: 0,   memo: "zero item",      date: Date.new(2024, 1, 1)) }
  let(:item_b) { create_mapped_item(amount_cents: 100, memo: "alpha payment",  date: Date.new(2024, 1, 2)) }
  let(:item_c) { create_mapped_item(amount_cents: 150, memo: "alpha refund",   date: Date.new(2024, 1, 3)) }
  let(:item_d) { create_mapped_item(amount_cents: 200, memo: "beta refund",    date: Date.new(2024, 2, 1)) }
  let(:item_e) { create_mapped_item(amount_cents: 300, memo: "beta payment",   date: Date.new(2024, 2, 15)) }
  let(:item_f) { create_mapped_item(amount_cents: 500, memo: "gamma payment",  date: Date.new(2024, 3, 1)) }
  let(:item_g) { create_mapped_item(amount_cents: 100, memo: "delta payment",  date: Date.new(2024, 3, 15)) }

  # Ensure all items are created before each test
  before { [item_a, item_b, item_c, item_d, item_e, item_f, item_g] }

  def create_mapped_item(**attrs)
    item = create(:ledger_item, **attrs)
    Ledger::Mapping.create(ledger: test_ledger, ledger_item: item, on_primary_ledger: true)
    item
  end

  def execute_query(query)
    described_class.new(query).execute(ledgers: [test_ledger.id])
  end

  def ids_of(*items)
    items.map(&:id)
  end

  describe "predicates" do
    context "numeric comparisons" do
      it "$gt generates greater than" do
        result = execute_query({ amount_cents: { "$gt" => 100 } })

        expect(result.to_sql).to match(/amount_cents > 100/)
        expect(result.pluck(:id)).to match_array(ids_of(item_c, item_d, item_e, item_f))
      end

      it "$lt generates less than" do
        result = execute_query({ amount_cents: { "$lt" => 200 } })

        expect(result.to_sql).to match(/amount_cents < 200/)
        expect(result.pluck(:id)).to match_array(ids_of(item_a, item_b, item_c, item_g))
      end

      it "$gte generates greater than or equal" do
        result = execute_query({ amount_cents: { "$gte" => 100 } })

        expect(result.to_sql).to match(/amount_cents >= 100/)
        expect(result.pluck(:id)).to match_array(ids_of(item_b, item_c, item_d, item_e, item_f, item_g))
      end

      it "$lte generates less than or equal" do
        result = execute_query({ amount_cents: { "$lte" => 100 } })

        expect(result.to_sql).to match(/amount_cents <= 100/)
        expect(result.pluck(:id)).to match_array(ids_of(item_a, item_b, item_g))
      end

      it "combines multiple operators on same field with AND (range query)" do
        result = execute_query({ amount_cents: { "$gt" => 100, "$lt" => 300 } })

        expect(result.to_sql).to match(/amount_cents > 100/)
        expect(result.to_sql).to match(/amount_cents < 300/)
        expect(result.pluck(:id)).to match_array(ids_of(item_c, item_d))
      end
    end

    context "equality" do
      it "implicit equality" do
        result = execute_query({ amount_cents: 100 })

        expect(result.to_sql).to match(/"amount_cents" = 100/)
        expect(result.pluck(:id)).to match_array(ids_of(item_b, item_g))
      end

      it "$eq explicit equality" do
        result = execute_query({ amount_cents: { "$eq" => 100 } })

        expect(result.to_sql).to match(/"amount_cents" = 100/)
        expect(result.pluck(:id)).to match_array(ids_of(item_b, item_g))
      end

      it "$ne generates not equal" do
        result = execute_query({ amount_cents: { "$ne" => 100 } })

        expect(result.to_sql).to match(/"amount_cents" != 100/)
        expect(result.pluck(:id)).to match_array(ids_of(item_a, item_c, item_d, item_e, item_f))
      end
    end

    context "string equality" do
      it "matches exact string with implicit equality" do
        result = execute_query({ memo: "alpha payment" })

        expect(result.to_sql).to match(/"memo" = 'alpha payment'/)
        expect(result.pluck(:id)).to match_array(ids_of(item_b))
      end

      it "$eq matches exact string" do
        result = execute_query({ memo: { "$eq" => "beta refund" } })

        expect(result.to_sql).to match(/"memo" = 'beta refund'/)
        expect(result.pluck(:id)).to match_array(ids_of(item_d))
      end

      it "$ne excludes exact string" do
        result = execute_query({ memo: { "$ne" => "gamma payment" } })

        expect(result.to_sql).to match(/"memo" != 'gamma payment'/)
        expect(result.pluck(:id)).to match_array(ids_of(item_a, item_b, item_c, item_d, item_e, item_g))
      end
    end

    context "array operators" do
      it "$in generates IN clause" do
        result = execute_query({ amount_cents: { "$in" => [100, 300] } })

        expect(result.to_sql).to match(/"amount_cents" IN \(100, 300\)/)
        expect(result.pluck(:id)).to match_array(ids_of(item_b, item_e, item_g))
      end

      it "$nin generates NOT IN clause" do
        result = execute_query({ amount_cents: { "$nin" => [0, 500] } })

        expect(result.to_sql).to match(/"amount_cents" NOT IN \(0, 500\)/)
        expect(result.pluck(:id)).to match_array(ids_of(item_b, item_c, item_d, item_e, item_g))
      end
    end

    context "null handling (SQL generation only)" do
      # Note: All permitted columns (memo, amount_cents, date) are required by model validation
      # These tests verify correct SQL generation without record assertions
      it "implicit null generates IS NULL" do
        result = execute_query({ memo: nil })
        expect(result.to_sql).to match(/"memo" IS NULL/)
      end

      it "$eq null generates IS NULL" do
        result = execute_query({ memo: { "$eq" => nil } })
        expect(result.to_sql).to match(/"memo" IS NULL/)
      end

      it "$ne null generates IS NOT NULL" do
        result = execute_query({ memo: { "$ne" => nil } })
        expect(result.to_sql).to match(/"memo" IS NOT NULL/)
      end
    end
  end

  describe "logical operators" do
    context "$and" do
      it "combines conditions with AND" do
        result = execute_query({
                                 "$and" => [
                                   { amount_cents: { "$gt" => 100 } },
                                   { amount_cents: { "$lt" => 300 } }
                                 ]
                               })

        expect(result.to_sql).to match(/amount_cents > 100/)
        expect(result.to_sql).to match(/amount_cents < 300/)
        expect(result.pluck(:id)).to match_array(ids_of(item_c, item_d))
      end

      it "handles empty $and array" do
        result = execute_query({ "$and" => [] })

        expect { result.to_sql }.not_to raise_error
        # Empty $and should return all items (no filtering)
        expect(result.pluck(:id)).to match_array(ids_of(item_a, item_b, item_c, item_d, item_e, item_f, item_g))
      end
    end

    context "$or" do
      it "combines conditions with OR" do
        result = execute_query({
                                 "$or" => [
                                   { amount_cents: 0 },
                                   { amount_cents: 500 }
                                 ]
                               })

        expect(result.to_sql).to match(/OR/)
        expect(result.pluck(:id)).to match_array(ids_of(item_a, item_f))
      end

      it "handles empty $or array" do
        result = execute_query({ "$or" => [] })

        expect { result.to_sql }.not_to raise_error
        # Empty $or should return no items
        expect(result.pluck(:id)).to be_empty
      end
    end

    context "$not" do
      it "negates a string condition" do
        result = execute_query({ "$not" => { memo: "beta refund" } })

        expect(result.to_sql).to match(/NOT/)
        # All items except item_d (which has memo "beta refund")
        expect(result.pluck(:id)).to match_array(ids_of(item_a, item_b, item_c, item_e, item_f, item_g))
      end

      it "negates a numeric condition" do
        result = execute_query({ "$not" => { amount_cents: 100 } })

        expect(result.to_sql).to match(/NOT/)
        # All items except item_b and item_g (which have amount_cents = 100)
        expect(result.pluck(:id)).to match_array(ids_of(item_a, item_c, item_d, item_e, item_f))
      end
    end

    context "nesting" do
      it "$and containing $or" do
        # amount > 100 AND (memo = 'alpha refund' OR memo = 'beta payment')
        result = execute_query({
                                 "$and" => [
                                   { amount_cents: { "$gt" => 100 } },
                                   { "$or" => [
                                     { memo: "alpha refund" },
                                     { memo: "beta payment" }
                                   ]
}
                                 ]
                               })

        expect(result.to_sql).to match(/amount_cents > 100/)
        expect(result.to_sql).to match(/OR/)
        expect(result.pluck(:id)).to match_array(ids_of(item_c, item_e))
      end

      it "$or containing $and" do
        # (amount >= 100 AND amount <= 100) OR (amount >= 300 AND amount <= 300)
        # Effectively: amount = 100 OR amount = 300
        result = execute_query({
                                 "$or" => [
                                   { "$and" => [
                                     { amount_cents: { "$gte" => 100 } },
                                     { amount_cents: { "$lte" => 100 } }
                                   ]
},
                                   { "$and" => [
                                     { amount_cents: { "$gte" => 300 } },
                                     { amount_cents: { "$lte" => 300 } }
                                   ]
}
                                 ]
                               })

        expect(result.to_sql).to match(/amount_cents.*AND.*amount_cents.*OR.*amount_cents.*AND.*amount_cents/)
        expect(result.pluck(:id)).to match_array(ids_of(item_b, item_e, item_g))
      end

      it "deeply nested query" do
        # (amount = 0) OR (amount > 100 AND memo = 'gamma payment')
        result = execute_query({
                                 "$or" => [
                                   { amount_cents: 0 },
                                   { "$and" => [
                                     { amount_cents: { "$gt" => 100 } },
                                     { memo: "gamma payment" }
                                   ]
}
                                 ]
                               })

        expect(result.to_sql).to match(/OR/)
        expect(result.pluck(:id)).to match_array(ids_of(item_a, item_f))
      end
    end
  end

  describe "error handling" do
    it "raises on unsupported logical operator" do
      query = { "$xor" => [{ amount_cents: 100 }] }
      expect { described_class.new(query).execute }.to raise_error(Ledger::Query::Error, /Unsupported logical operator/)
    end

    it "raises on unsupported comparison operator" do
      query = { amount_cents: { "$regex" => ".*" } }
      expect { described_class.new(query).execute }.to raise_error(Ledger::Query::Error, /Unsupported operator/)
    end

    it "raises on non-hash query" do
      expect { described_class.new("invalid") }.to raise_error(Ledger::Query::Error, /must be a Hash/)
    end

    it "raises on invalid column name" do
      query = { invalid_column: 100 }
      expect { described_class.new(query).execute }.to raise_error(Ledger::Query::Error, /Invalid column name/)
    end
  end

  describe "ledger scoping" do
    let(:other_event) { create(:event) }
    let(:other_ledger) { other_event.ledger }
    let(:other_item) { create_other_ledger_item(amount_cents: 100, memo: "other ledger item") }

    before { other_item }

    def create_other_ledger_item(**attrs)
      item = create(:ledger_item, **attrs)
      Ledger::Mapping.create(ledger: other_ledger, ledger_item: item, on_primary_ledger: true)
      item
    end

    it "scopes to single ledger when provided" do
      result = execute_query({ amount_cents: 100 })

      expect(result.to_sql).to match(/ledger_mappings/)
      expect(result.pluck(:id)).to match_array(ids_of(item_b, item_g))
      expect(result.pluck(:id)).not_to include(other_item.id)
    end

    it "scopes to multiple ledgers" do
      result = described_class.new({ amount_cents: 100 }).execute(ledgers: [test_ledger.id, other_ledger.id])

      expect(result.to_sql).to match(/ledger_mappings/)
      expect(result.to_sql).to match(/IN/)
      expect(result.pluck(:id)).to match_array(ids_of(item_b, item_g, other_item))
    end

    it "returns all items when ledgers is empty" do
      result = described_class.new({ amount_cents: 100 }).execute(ledgers: [])

      expect(result.to_sql).not_to match(/ledger_mappings/)
      # Will include items from any ledger (including test items and other_item)
      expect(result.pluck(:id)).to include(item_b.id, item_g.id, other_item.id)
    end
  end

  describe "complex queries" do
    it "filters with multiple field conditions" do
      # amount > 0 AND memo contains 'payment' (using $in for specific values)
      result = execute_query({
                               "$and" => [
                                 { amount_cents: { "$gt" => 0 } },
                                 { memo: { "$in" => ["alpha payment", "beta payment", "gamma payment", "delta payment"] } }
                               ]
                             })

      expect(result.pluck(:id)).to match_array(ids_of(item_b, item_e, item_f, item_g))
    end

    it "combines $not with $and" do
      # NOT(amount = 100) AND memo IS NOT NULL
      # Since all memos are non-null, this effectively just excludes items with amount_cents = 100
      result = execute_query({
                               "$and" => [
                                 { "$not" => { amount_cents: 100 } },
                                 { memo: { "$ne" => nil } }
                               ]
                             })

      # All items except item_b and item_g (which have amount_cents = 100)
      expect(result.pluck(:id)).to match_array(ids_of(item_a, item_c, item_d, item_e, item_f))
    end

    it "handles $or with $not" do
      # amount = 0 OR NOT(memo = 'gamma payment')
      result = execute_query({
                               "$or" => [
                                 { amount_cents: 0 },
                                 { "$not" => { memo: "gamma payment" } }
                               ]
                             })

      # item_a (amount=0) + all items except item_f (gamma payment)
      expect(result.pluck(:id)).to match_array(ids_of(item_a, item_b, item_c, item_d, item_e, item_g))
    end
  end
end
