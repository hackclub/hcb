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
  let(:item_a) { create_mapped_item(amount_cents: 0,   memo: "zero item",      datetime: Date.new(2024, 1, 1)) }
  let(:item_b) { create_mapped_item(amount_cents: 100, memo: "alpha payment",  datetime: Date.new(2024, 1, 2)) }
  let(:item_c) { create_mapped_item(amount_cents: 150, memo: "alpha refund",   datetime: Date.new(2024, 1, 3)) }
  let(:item_d) { create_mapped_item(amount_cents: 200, memo: "beta refund",    datetime: Date.new(2024, 2, 1)) }
  let(:item_e) { create_mapped_item(amount_cents: 300, memo: "beta payment",   datetime: Date.new(2024, 2, 15)) }
  let(:item_f) { create_mapped_item(amount_cents: 500, memo: "gamma payment",  datetime: Date.new(2024, 3, 1)) }
  let(:item_g) { create_mapped_item(amount_cents: 100, memo: "delta payment",  datetime: Date.new(2024, 3, 15)) }

  # Ensure all items are created before each test
  before { [item_a, item_b, item_c, item_d, item_e, item_f, item_g] }

  def create_mapped_item(**attrs)
    item = create(:ledger_item, **attrs)
    Ledger::Mapping.create(ledger: test_ledger, ledger_item: item, on_primary_ledger: true)
    # refresh! (triggered on create and on mapping) recomputes memo and
    # amount_cents from canonical transactions, which these items don't have.
    # Pin the intended values, bypassing callbacks.
    item.update_columns(**attrs)
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

        expect(result.to_sql).to match(/"amount_cents" > 100/)
        expect(result.pluck(:id)).to match_array(ids_of(item_c, item_d, item_e, item_f))
      end

      it "$lt generates less than" do
        result = execute_query({ amount_cents: { "$lt" => 200 } })

        expect(result.to_sql).to match(/"amount_cents" < 200/)
        expect(result.pluck(:id)).to match_array(ids_of(item_a, item_b, item_c, item_g))
      end

      it "$gte generates greater than or equal" do
        result = execute_query({ amount_cents: { "$gte" => 100 } })

        expect(result.to_sql).to match(/"amount_cents" >= 100/)
        expect(result.pluck(:id)).to match_array(ids_of(item_b, item_c, item_d, item_e, item_f, item_g))
      end

      it "$lte generates less than or equal" do
        result = execute_query({ amount_cents: { "$lte" => 100 } })

        expect(result.to_sql).to match(/"amount_cents" <= 100/)
        expect(result.pluck(:id)).to match_array(ids_of(item_a, item_b, item_g))
      end

      it "combines multiple operators on same field with AND (range query)" do
        result = execute_query({ amount_cents: { "$gt" => 100, "$lt" => 300 } })

        expect(result.to_sql).to match(/"amount_cents" > 100/)
        expect(result.to_sql).to match(/"amount_cents" < 300/)
        expect(result.pluck(:id)).to match_array(ids_of(item_c, item_d))
      end
    end

    context "datetime comparisons" do
      # Item datetimes: a-c in Jan 2024, d-e in Feb, f-g in Mar. Boundaries sit
      # between item days so time-zone offsets can't flip the results.
      it "$gte with an ISO 8601 string" do
        result = execute_query({ datetime: { "$gte" => "2024-01-20" } })

        expect(result.pluck(:id)).to match_array(ids_of(item_d, item_e, item_f, item_g))
      end

      it "$lt with a Date object" do
        result = execute_query({ datetime: { "$lt" => Date.new(2024, 1, 20) } })

        expect(result.pluck(:id)).to match_array(ids_of(item_a, item_b, item_c))
      end

      it "combines bounds into a range" do
        result = execute_query({ datetime: { "$gte" => "2024-01-20", "$lt" => "2024-03-10" } })

        expect(result.pluck(:id)).to match_array(ids_of(item_d, item_e, item_f))
      end

      it "raises on a non-ISO 8601 string" do
        expect {
          execute_query({ datetime: { "$gte" => "not-a-date" } })
        }.to raise_error(Ledger::Query::Error, /Invalid ISO 8601/)
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

    context "string comparisons" do
      it "$gt compares strings lexicographically" do
        result = execute_query({ memo: { "$gt" => "delta payment" } })

        # Only "gamma payment" and "zero item" sort after "delta payment".
        expect(result.pluck(:id)).to match_array(ids_of(item_f, item_a))
      end

      it "$lte compares strings lexicographically" do
        result = execute_query({ memo: { "$lte" => "alpha refund" } })

        expect(result.pluck(:id)).to match_array(ids_of(item_b, item_c))
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
      # Note: All permitted columns (memo, amount_cents, datetime) are required by model validation
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

    context "$ne / $nin on a nullable column (MongoDB null semantics)" do
      # linked_object_type is nullable and NULL for every shared item. MongoDB's
      # $ne/$nin match documents where the field is missing/null, unlike a bare
      # SQL != / NOT IN, which drops NULL rows.
      before { item_b.update_columns(linked_object_type: "Invoice") }

      it "$ne includes rows where the column is NULL" do
        result = execute_query({ linked_object_type: { "$ne" => "Invoice" } })

        expect(result.pluck(:id)).to match_array(ids_of(item_a, item_c, item_d, item_e, item_f, item_g))
      end

      it "$nin includes rows where the column is NULL" do
        result = execute_query({ linked_object_type: { "$nin" => ["Invoice"] } })

        expect(result.pluck(:id)).to match_array(ids_of(item_a, item_c, item_d, item_e, item_f, item_g))
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

        expect(result.to_sql).to match(/"amount_cents" > 100/)
        expect(result.to_sql).to match(/"amount_cents" < 300/)
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

    context "$nor" do
      it "negates a string condition" do
        result = execute_query({ "$nor" => [{ memo: "beta refund" }] })

        expect(result.to_sql).to match(/NOT/)
        # All items except item_d (which has memo "beta refund")
        expect(result.pluck(:id)).to match_array(ids_of(item_a, item_b, item_c, item_e, item_f, item_g))
      end

      it "negates the union of its conditions" do
        result = execute_query({ "$nor" => [{ amount_cents: 0 }, { amount_cents: 500 }] })

        # NOT (amount = 0 OR amount = 500): all items except item_a and item_f
        expect(result.pluck(:id)).to match_array(ids_of(item_b, item_c, item_d, item_e, item_g))
      end

      it "raises when given a hash instead of an array" do
        expect { execute_query({ "$nor" => { amount_cents: 100 } }) }.to raise_error(Ledger::Query::Error, /\$nor.*array/i)
      end
    end

    context "field-level $not" do
      it "negates an inner operator expression" do
        result = execute_query({ amount_cents: { "$not" => { "$gt" => 100 } } })

        # NOT (amount > 100): amount <= 100 → item_a, item_b, item_g
        expect(result.pluck(:id)).to match_array(ids_of(item_a, item_b, item_g))
      end

      it "matches NULL rows, mirroring MongoDB" do
        item_b.update_columns(linked_object_type: "Invoice")

        result = execute_query({ linked_object_type: { "$not" => { "$eq" => "Invoice" } } })

        # NOT (type = Invoice): every item except item_b, including the NULL-typed rows
        expect(result.pluck(:id)).to match_array(ids_of(item_a, item_c, item_d, item_e, item_f, item_g))
      end
    end

    context "top-level $not (removed in favor of $nor)" do
      it "is no longer a supported logical operator" do
        expect { execute_query({ "$not" => { amount_cents: 100 } }) }.to raise_error(Ledger::Query::Error, /Unsupported logical operator/)
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

        expect(result.to_sql).to match(/"amount_cents" > 100/)
        expect(result.to_sql).to match(/OR/)
        expect(result.pluck(:id)).to match_array(ids_of(item_c, item_e))
      end

      it "$and containing $or on the same column" do
        # amount < 300 AND (amount <= 0 OR amount >= 200)
        # Regression: Relation#merge replaces same-column conditions instead of
        # ANDing them, which silently dropped the outer amount condition.
        result = execute_query({
                                 "$and" => [
                                   { amount_cents: { "$lt" => 300 } },
                                   { "$or" => [
                                     { amount_cents: { "$lte" => 0 } },
                                     { amount_cents: { "$gte" => 200 } }
                                   ]
}
                                 ]
                               })

        expect(result.to_sql).to match(/"amount_cents" < 300/)
        expect(result.pluck(:id)).to match_array(ids_of(item_a, item_d))
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

        expect(result.to_sql).to match(/amount_cents.*OR.*amount_cents.*AND.*memo/)
        expect(result.pluck(:id)).to match_array(ids_of(item_a, item_f))
      end
    end
  end

  describe "$search" do
    it "matches items by memo full-text search" do
      result = execute_query({ memo: { "$search" => "alpha" } })

      expect(result.pluck(:id)).to match_array(ids_of(item_b, item_c))
    end

    it "raises when $search is used on a field other than memo" do
      query = { amount_cents: { "$search" => "100" } }
      expect { described_class.new(query).execute }.to raise_error(Ledger::Query::Error, /\$search is only supported on the memo field/)
    end
  end

  describe "error handling" do
    it "raises on unsupported logical operator" do
      query = { "$xor" => [{ amount_cents: 100 }] }
      expect { described_class.new(query).execute }.to raise_error(Ledger::Query::Error, /Unsupported logical operator/)
    end

    it "raises on unsupported comparison operator" do
      query = { amount_cents: { "$regex" => ".*" } }
      expect { described_class.new(query).execute }.to raise_error(Ledger::Query::Error, /Unsupported comparison operator/)
    end

    it "raises on non-hash query" do
      expect { described_class.new("invalid") }.to raise_error(Ledger::Query::Error, /must be a Hash/)
    end

    it "raises on invalid field name" do
      query = { invalid_column: 100 }
      expect { described_class.new(query).execute }.to raise_error(Ledger::Query::Error, /Invalid field name/)
    end

    it "raises when $and is given a hash instead of an array" do
      query = { "$and" => { amount_cents: { "$lte" => 100 } } }
      expect { described_class.new(query).execute }.to raise_error(Ledger::Query::Error, /\$and.*array/i)
    end

    it "raises when $or is given a hash instead of an array" do
      query = { "$or" => { amount_cents: 100 } }
      expect { described_class.new(query).execute }.to raise_error(Ledger::Query::Error, /\$or.*array/i)
    end

    it "raises on an array operand for $eq (use $in for membership)" do
      query = { amount_cents: { "$eq" => [100, 300] } }
      expect { described_class.new(query).execute }.to raise_error(Ledger::Query::Error, /array/i)
    end

    it "raises on an array operand for implicit equality" do
      query = { amount_cents: [100, 300] }
      expect { described_class.new(query).execute }.to raise_error(Ledger::Query::Error, /array/i)
    end

    it "raises with a clear message when $in is given a non-array operand" do
      query = { amount_cents: { "$in" => 5 } }
      expect { described_class.new(query).execute }.to raise_error(Ledger::Query::Error, /\$in.*array/i)
    end

    it "rejects a query nested beyond the depth limit" do
      query = { amount_cents: 1 }
      25.times { query = { "$and" => [query] } }

      expect { described_class.new(query) }.to raise_error(Ledger::Query::Error, /deep|nesting/i)
    end

    it "rejects a query with too many conditions" do
      query = { "$or" => Array.new(250) { |i| { amount_cents: i } } }

      expect { described_class.new(query) }.to raise_error(Ledger::Query::Error, /too many|conditions/i)
    end

    it "rejects an oversized array operand (e.g. a huge $in list)" do
      query = { amount_cents: { "$in" => (1..2000).to_a } }

      expect { described_class.new(query) }.to raise_error(Ledger::Query::Error, /array|too large|elements/i)
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
      item.update_columns(**attrs)
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

    it "returns no items when ledgers is empty" do
      result = described_class.new({ amount_cents: 100 }).execute(ledgers: [])

      expect(result.pluck(:id)).to be_empty
    end

    it "queries across all ledgers only when all_ledgers is explicitly requested" do
      result = described_class.new({ amount_cents: 100 }).execute(all_ledgers: true)

      expect(result.to_sql).not_to match(/ledger_mappings/)
      expect(result.pluck(:id)).to include(item_b.id, item_g.id, other_item.id)
    end

    it "does not treat a truthy non-boolean all_ledgers as an opt-in to skip scoping" do
      result = described_class.new({ amount_cents: 100 }).execute(all_ledgers: "false")

      expect(result.to_sql).to match(/ledger_mappings/)
      expect(result.pluck(:id)).to be_empty
    end

    it "only returns matches from the requested ledger when combined with $search" do
      other_payment_item = create_other_ledger_item(amount_cents: 400, memo: "other payment")

      result = execute_query({ memo: { "$search" => "payment" } })

      expect(result.pluck(:id)).to match_array(ids_of(item_b, item_e, item_f, item_g))
      expect(result.pluck(:id)).not_to include(other_payment_item.id)
    end

    it "includes $search matches from every requested ledger when multiple are given" do
      other_payment_item = create_other_ledger_item(amount_cents: 400, memo: "other payment")

      result = described_class.new({ memo: { "$search" => "payment" } }).execute(ledgers: [test_ledger.id, other_ledger.id])

      expect(result.pluck(:id)).to match_array(ids_of(item_b, item_e, item_f, item_g, other_payment_item))
    end

    it "scopes the $search subquery itself to the requested ledgers, not just the final result" do
      # The $search subquery is a separate query.rb code path from every other
      # predicate (it wraps pg_search's own scope rather than a plain `where`),
      # so it needs its own assertion that the ledger scope reaches it: a
      # `FROM "ledger_mappings"` subquery for the search itself, plus one for
      # the outer result set — not just the outer one alone.
      result = execute_query({ memo: { "$search" => "payment" } })

      expect(result.to_sql.scan(/FROM "ledger_mappings"/).count).to eq(2)
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

    it "combines $nor with $and" do
      # NOT(amount = 100) AND memo IS NOT NULL
      # Since all memos are non-null, this effectively just excludes items with amount_cents = 100
      result = execute_query({
                               "$and" => [
                                 { "$nor" => [{ amount_cents: 100 }] },
                                 { memo: { "$ne" => nil } }
                               ]
                             })

      # All items except item_b and item_g (which have amount_cents = 100)
      expect(result.pluck(:id)).to match_array(ids_of(item_a, item_c, item_d, item_e, item_f))
    end

    it "handles $or with $nor" do
      # amount = 0 OR NOT(memo = 'gamma payment')
      result = execute_query({
                               "$or" => [
                                 { amount_cents: 0 },
                                 { "$nor" => [{ memo: "gamma payment" }] }
                               ]
                             })

      # item_a (amount=0) + all items except item_f (gamma payment)
      expect(result.pluck(:id)).to match_array(ids_of(item_a, item_b, item_c, item_d, item_e, item_g))
    end
  end
end
