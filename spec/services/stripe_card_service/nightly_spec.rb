# frozen_string_literal: true

require "rails_helper"

RSpec.describe StripeCardService::Nightly, type: :service do
  describe "#run" do
    let!(:canonical_transaction) { create(:canonical_transaction, memo: "HCKCLB Issued card fee") }

    it "renames the canonical transaction" do
      described_class.new.run

      expect(canonical_transaction.reload.custom_memo).to eq("💳 New user card fee")
    end

    # `custom_memo` lives on the canonical transaction *and* on its ledger item,
    # which caches `memo` from its own copy. Renaming has to write both, or the
    # ledger keeps showing the raw bank memo.
    it "renames the canonical transaction's ledger item" do
      described_class.new.run

      ledger_item = canonical_transaction.reload.ledger_item
      expect(ledger_item.reload.custom_memo).to eq("💳 New user card fee")
      expect(ledger_item.memo).to eq("💳 New user card fee")
    end

    it "leaves an already renamed transaction alone" do
      canonical_transaction.local_hcb_code.update_custom_memo!("Renamed by an organizer")

      described_class.new.run

      expect(canonical_transaction.reload.custom_memo).to eq("Renamed by an organizer")
      expect(canonical_transaction.ledger_item.reload.custom_memo).to eq("Renamed by an organizer")
    end
  end
end
