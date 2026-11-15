# frozen_string_literal: true

require "rails_helper"

RSpec.describe TransactionGroupingEngine::Transaction::All do
  describe "#run" do
    it "returns an empty array if there are no transactions" do
      event = create(:event)

      expect(described_class.new(event_id: event.id).run).to be_empty
    end

    it "returns transactions for the given event" do
      events = create_list(:event, 2)

      events.each do |event|
        ["transaction_1", "transaction_2"].each do |memo|
          create(
            :canonical_event_mapping,
            event: event,
            canonical_transaction: create(:canonical_transaction, memo:)
          )
        end
      end

      results = described_class.new(event_id: events.first.id).run
      expect(results.size).to eq(2)
      expect(results.map(&:event)).to all(eq(events.first))
      expect(results.map(&:memo)).to contain_exactly("TRANSACTION_1", "TRANSACTION_2")
    end

    it "filters by category, including transactions with a split in it" do
      event = create(:event)
      category = TransactionCategory.find_or_create_by!(slug: "rent")

      whole = create(:canonical_transaction, memo: "whole", category_slug: "rent", event:)
      split = create(:canonical_transaction, memo: "split", amount_cents: -100, event:)
      split.splits.create!(amount_cents: -40, category:)
      create(:canonical_transaction, memo: "neither", event:)

      # Fronted pending transactions are listed alongside settled ones; the
      # rest come from the pending engine.
      # Pending factory transactions take ids no settled one shares, or a pair
      # on the same id would get the same `HCB-000-<id>` code and be grouped.
      create_pending = ->(**attrs) { create(:canonical_pending_transaction, id: [CanonicalTransaction.maximum(:id).to_i, CanonicalPendingTransaction.maximum(:id).to_i].max + 1_000, amount_cents: -100, event:, **attrs) }
      fronted, pending = [true, false].map do |is_fronted|
        create_pending.call(fronted: is_fronted).tap { |cpt| cpt.splits.create!(amount_cents: -40, category:) }
      end
      create_pending.call(fronted: true)
      create_pending.call

      expect(described_class.new(event_id: event.id, category:).run.map(&:hcb_code)).to contain_exactly(whole.hcb_code, split.hcb_code, fronted.hcb_code)
      expect(PendingTransactionEngine::PendingTransaction::All.new(event_id: event.id, category:).run.map(&:hcb_code)).to contain_exactly(pending.hcb_code)
    end

    it "allows filtering by memo" do
      event = create(:event)

      snack = create(
        :canonical_transaction,
        memo: "SHELBURNE MARKET",
        custom_memo: "Snacks at Shelburne Market"
      )
      create(:canonical_event_mapping, event: event, canonical_transaction: snack)

      sharks = create(
        :canonical_transaction,
        memo: "IKEA 111111111",
        custom_memo: "A shiver of Blåhaj"
      )
      create(:canonical_event_mapping, event: event, canonical_transaction: sharks)

      ["snAck", "mARKet"].each do |search|
        result = described_class.new(event_id: event.id, search:).all.sole
        expect(JSON.parse(result.raw_canonical_transaction_ids)).to contain_exactly(snack.id)
      end

      ["shiver", "IKEA"].each do |search|
        result = described_class.new(event_id: event.id, search:).all.sole
        expect(JSON.parse(result.raw_canonical_transaction_ids)).to contain_exactly(sharks.id)
      end
    end

    it "escapes the search string" do
      event = create(:event)

      transaction = create(
        :canonical_transaction,
        memo: "; DROP TABLE",
        custom_memo: "%%%LOL%%%:oops ?"
      )
      create(:canonical_event_mapping, event: event, canonical_transaction: transaction)

      [":oops ?", "%%%lol"].each do |search|
        result = described_class.new(event_id: event.id, search: ":oops ?").all.sole
        expect(JSON.parse(result.raw_canonical_transaction_ids)).to contain_exactly(transaction.id)
      end
    end
  end
end
