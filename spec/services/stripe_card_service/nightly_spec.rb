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

    # Renaming goes through the whole HCB code group, so a fee transaction that
    # shares a group with an organizer-renamed transaction must be left alone
    # rather than stamping the default memo over it.
    it "leaves a group alone when a sibling transaction carries an organizer's memo" do
      sibling = create(:canonical_transaction)
      sibling.update_column(:hcb_code, canonical_transaction.hcb_code)
      # Renamed before this group write existed, so the fee transaction next to it
      # is still `without_custom_memo` and the nightly still picks it up.
      sibling.update_column(:custom_memo, "Organizer's name for this")

      described_class.new.run

      expect(sibling.reload.custom_memo).to eq("Organizer's name for this")
    end

    it "leaves an already renamed transaction alone" do
      canonical_transaction.local_hcb_code.update_custom_memo!("Renamed by an organizer")

      described_class.new.run

      expect(canonical_transaction.reload.custom_memo).to eq("Renamed by an organizer")
      expect(canonical_transaction.ledger_item.reload.custom_memo).to eq("Renamed by an organizer")
    end
  end
end
