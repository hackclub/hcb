# frozen_string_literal: true

require "rails_helper"

RSpec.describe MoneyPrinterStatsJob do
  describe ".compute_stats" do
    # Old engine balance: sum of mapped canonical transactions.
    def set_old_balance(event, amount_cents)
      ct = create(:canonical_transaction, amount_cents:)
      create(:canonical_event_mapping, canonical_transaction: ct, event:)
    end

    # New engine balance: ledger item mapped onto the org's primary ledger.
    def set_new_balance(event, amount_cents)
      ct = create(:canonical_transaction, amount_cents:)
      create(:canonical_event_mapping, canonical_transaction: ct, event:)
      item = create(:ledger_item, amount_cents:, canonical_transactions: [ct])
      create(:ledger_mapping, :on_primary, ledger: event.ledger, ledger_item: item)
    end

    it "computes net delta, totals, accuracy counts, and the leaderboard" do
      printing = create(:event)
      set_old_balance(printing, 1_000)
      set_new_balance(printing, 6_000) # delta +5_000

      shredding = create(:event)
      set_old_balance(shredding, 3_000)
      set_new_balance(shredding, 500) # delta -2_500

      matching = create(:event)
      set_old_balance(matching, 2_000)
      set_new_balance(matching, 2_000) # delta 0

      stats = described_class.compute_stats

      expect(stats[:sum_old_cents]).to eq(6_000)
      expect(stats[:sum_new_cents]).to eq(8_500)
      expect(stats[:net_delta_cents]).to eq(2_500)
      expect(stats[:total_orgs]).to eq(3)
      expect(stats[:matching_orgs]).to eq(1)
      expect(stats[:leaderboard].map { |e| e[:delta_cents] }).to eq([5_000, -2_500])
      expect(stats[:leaderboard].first).to include(
        public_id: printing.public_id,
        slug: printing.slug,
        name: printing.name
      )
    end

    it "treats an organization without a ledger as zero new balance" do
      event = create(:event)
      set_old_balance(event, 1_000)
      event.ledger.destroy!

      stats = described_class.compute_stats

      expect(stats[:sum_new_cents]).to eq(0)
      expect(stats[:net_delta_cents]).to eq(-1_000)
      expect(stats[:leaderboard].first[:delta_cents]).to eq(-1_000)
    end
  end
end
