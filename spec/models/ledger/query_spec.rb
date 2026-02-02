# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledger::Query, type: :model do
  describe "predicates" do
    context "numeric comparisons" do
      it "$gt generates greater than" do
        sql = described_class.new({ amount_cents: { "$gt" => 100 } }).execute.to_sql
        expect(sql).to match(/amount_cents > 100/)
      end

      it "$lt generates less than" do
        sql = described_class.new({ amount_cents: { "$lt" => 500 } }).execute.to_sql
        expect(sql).to match(/amount_cents < 500/)
      end

      it "$gte generates greater than or equal" do
        sql = described_class.new({ amount_cents: { "$gte" => 100 } }).execute.to_sql
        expect(sql).to match(/amount_cents >= 100/)
      end

      it "$lte generates less than or equal" do
        sql = described_class.new({ amount_cents: { "$lte" => 500 } }).execute.to_sql
        expect(sql).to match(/amount_cents <= 500/)
      end

      it "combines multiple operators on same field with AND" do
        sql = described_class.new({ amount_cents: { "$gt" => 100, "$lt" => 500 } }).execute.to_sql
        expect(sql).to match(/amount_cents > 100/)
        expect(sql).to match(/amount_cents < 500/)
      end
    end

    context "equality" do
      it "implicit equality" do
        sql = described_class.new({ amount_cents: 1000 }).execute.to_sql
        expect(sql).to match(/"amount_cents" = 1000/)
      end

      it "$eq explicit equality" do
        sql = described_class.new({ amount_cents: { "$eq" => 1000 } }).execute.to_sql
        expect(sql).to match(/"amount_cents" = 1000/)
      end

      it "$ne generates not equal" do
        sql = described_class.new({ amount_cents: { "$ne" => 1000 } }).execute.to_sql
        expect(sql).to match(/"amount_cents" != 1000/)
      end
    end

    context "string operators" do
      it "$ilike generates case-insensitive pattern match" do
        sql = described_class.new({ memo: { "$ilike" => "%test%" } }).execute.to_sql
        expect(sql).to match(/memo.*ILIKE.*%test%/i)
      end

      it "$like generates pattern match" do
        sql = described_class.new({ memo: { "$like" => "%test%" } }).execute.to_sql
        expect(sql).to match(/memo.*ILIKE.*%test%/i)
      end
    end

    context "array operators" do
      it "$in generates IN clause" do
        sql = described_class.new({ amount_cents: { "$in" => [100, 200, 300] } }).execute.to_sql
        expect(sql).to match(/"amount_cents" IN \(100, 200, 300\)/)
      end

      it "$nin generates NOT IN clause" do
        sql = described_class.new({ amount_cents: { "$nin" => [100, 200] } }).execute.to_sql
        expect(sql).to match(/"amount_cents" NOT IN \(100, 200\)/)
      end
    end

    context "null handling" do
      it "implicit null generates IS NULL" do
        sql = described_class.new({ marked_no_or_lost_receipt_at: nil }).execute.to_sql
        expect(sql).to match(/"marked_no_or_lost_receipt_at" IS NULL/)
      end

      it "$eq null generates IS NULL" do
        sql = described_class.new({ marked_no_or_lost_receipt_at: { "$eq" => nil } }).execute.to_sql
        expect(sql).to match(/"marked_no_or_lost_receipt_at" IS NULL/)
      end

      it "$ne null generates IS NOT NULL" do
        sql = described_class.new({ marked_no_or_lost_receipt_at: { "$ne" => nil } }).execute.to_sql
        expect(sql).to match(/"marked_no_or_lost_receipt_at" IS NOT NULL/)
      end
    end
  end

  describe "logical operators" do
    context "$and" do
      it "combines conditions with AND" do
        query = {
          "$and" => [
            { amount_cents: { "$gt" => 100 } },
            { amount_cents: { "$lt" => 500 } }
          ]
        }
        sql = described_class.new(query).execute.to_sql
        expect(sql).to match(/amount_cents > 100/)
        expect(sql).to match(/amount_cents < 500/)
      end

      it "handles empty $and array" do
        query = { "$and" => [] }
        expect { described_class.new(query).execute.to_sql }.not_to raise_error
      end
    end

    context "$or" do
      it "combines conditions with OR" do
        query = {
          "$or" => [
            { amount_cents: 100 },
            { amount_cents: 200 }
          ]
        }
        sql = described_class.new(query).execute.to_sql
        expect(sql).to match(/OR/)
      end

      it "handles empty $or array" do
        query = { "$or" => [] }
        expect { described_class.new(query).execute.to_sql }.not_to raise_error
      end
    end

    context "$not" do
      it "negates a condition" do
        query = { "$not" => { amount_cents: 100 } }
        sql = described_class.new(query).execute.to_sql
        expect(sql).to match(/NOT/)
      end
    end

    context "nesting" do
      it "$and containing $or" do
        query = {
          "$and" => [
            { amount_cents: { "$gt" => 0 } },
            { "$or" => [
              { memo: { "$ilike" => "%foo%" } },
              { memo: { "$ilike" => "%bar%" } }
            ] }
          ]
        }
        sql = described_class.new(query).execute.to_sql
        expect(sql).to match(/amount_cents > 0/)
        expect(sql).to match(/OR/)
      end

      it "$or containing $and" do
        query = {
          "$or" => [
            { "$and" => [
              { amount_cents: { "$gt" => 100 } },
              { amount_cents: { "$lt" => 200 } }
            ] },
            { "$and" => [
              { amount_cents: { "$gt" => 300 } },
              { amount_cents: { "$lt" => 400 } }
            ] }
          ]
        }
        sql = described_class.new(query).execute.to_sql
        expect(sql).to match(/OR/)
      end
    end
  end

  describe "error handling" do
    it "raises on unsupported logical operator" do
      query = { "$xor" => [{ amount_cents: 100 }] }
      expect { described_class.new(query).execute }.to raise_error(Ledger::Query::QueryError, /Unsupported logical operator/)
    end

    it "raises on unsupported comparison operator" do
      query = { amount_cents: { "$regex" => ".*" } }
      expect { described_class.new(query).execute }.to raise_error(Ledger::Query::QueryError, /Unsupported operator/)
    end
  end

  describe "ledger scoping" do
    it "scopes to ledger_id when provided" do
      sql = described_class.new({ amount_cents: 100 }).execute(ledger_id: 42).to_sql
      expect(sql).to match(/"ledger_id" = 42/)
      expect(sql).to match(/"amount_cents" = 100/)
    end
  end

  describe "integration", :db do
    let!(:item_100) { create(:ledger_item, amount_cents: 100, memo: "alpha payment") }
    let!(:item_200) { create(:ledger_item, amount_cents: 200, memo: "beta refund") }
    let!(:item_300) { create(:ledger_item, amount_cents: 300, memo: "alpha refund") }
    let!(:item_500) { create(:ledger_item, amount_cents: 500, memo: "gamma payment", marked_no_or_lost_receipt_at: Time.current) }

    it "filters with $gt" do
      result = described_class.new({ amount_cents: { "$gt" => 150 } }).execute
      expect(result.pluck(:id)).to match_array([item_200, item_300, item_500].map(&:id))
    end

    it "filters with $lt" do
      result = described_class.new({ amount_cents: { "$lt" => 250 } }).execute
      expect(result.pluck(:id)).to match_array([item_100, item_200].map(&:id))
    end

    it "filters with range ($gt and $lt)" do
      result = described_class.new({ amount_cents: { "$gt" => 150, "$lt" => 400 } }).execute
      expect(result.pluck(:id)).to match_array([item_200, item_300].map(&:id))
    end

    it "filters with $in" do
      result = described_class.new({ amount_cents: { "$in" => [100, 300] } }).execute
      expect(result.pluck(:id)).to match_array([item_100, item_300].map(&:id))
    end

    it "filters with $nin" do
      result = described_class.new({ amount_cents: { "$nin" => [100, 500] } }).execute
      expect(result.pluck(:id)).to match_array([item_200, item_300].map(&:id))
    end

    it "filters with $ilike" do
      result = described_class.new({ memo: { "$ilike" => "%alpha%" } }).execute
      expect(result.pluck(:id)).to match_array([item_100, item_300].map(&:id))
    end

    it "filters null values" do
      result = described_class.new({ marked_no_or_lost_receipt_at: nil }).execute
      expect(result.pluck(:id)).to match_array([item_100, item_200, item_300].map(&:id))
    end

    it "filters non-null values" do
      result = described_class.new({ marked_no_or_lost_receipt_at: { "$ne" => nil } }).execute
      expect(result.pluck(:id)).to match_array([item_500].map(&:id))
    end

    it "filters with $or" do
      result = described_class.new({
        "$or" => [
          { amount_cents: 100 },
          { amount_cents: 500 }
        ]
      }).execute
      expect(result.pluck(:id)).to match_array([item_100, item_500].map(&:id))
    end

    it "filters with $and" do
      result = described_class.new({
        "$and" => [
          { memo: { "$ilike" => "%refund%" } },
          { amount_cents: { "$gt" => 250 } }
        ]
      }).execute
      expect(result.pluck(:id)).to match_array([item_300].map(&:id))
    end

    it "filters with nested $and inside $or" do
      result = described_class.new({
        "$or" => [
          { "$and" => [
            { memo: { "$ilike" => "%alpha%" } },
            { amount_cents: { "$lt" => 150 } }
          ] },
          { amount_cents: 500 }
        ]
      }).execute
      expect(result.pluck(:id)).to match_array([item_100, item_500].map(&:id))
    end
  end
end
