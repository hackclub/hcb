# frozen_string_literal: true

require "rails_helper"

RSpec.describe HcbCode::Memo, type: :model do
  describe "#custom_memo" do
    let(:canonical_transaction) { create(:canonical_transaction) }
    let(:hcb_code) { canonical_transaction.local_hcb_code }

    it "reads from the ledger item" do
      hcb_code.ledger_item.update!(custom_memo: "From the ledger item")

      expect(hcb_code.reload.custom_memo).to eq("From the ledger item")
    end

    it "prefers the ledger item over the canonical transaction" do
      hcb_code.ledger_item.update!(custom_memo: "From the ledger item")
      canonical_transaction.update!(custom_memo: "From the canonical transaction")

      expect(hcb_code.reload.custom_memo).to eq("From the ledger item")
    end

    it "falls back to the canonical transaction when the ledger item has no custom memo" do
      canonical_transaction.update!(custom_memo: "From the canonical transaction")

      expect(hcb_code.reload.custom_memo).to eq("From the canonical transaction")
    end

    it "falls back to the canonical pending transaction when the ledger item has no custom memo" do
      pending_transaction = create(:canonical_pending_transaction, custom_memo: "From the pending transaction")
      pending_hcb_code = pending_transaction.local_hcb_code

      expect(pending_hcb_code.ledger_item&.custom_memo).to be_nil
      expect(pending_hcb_code.custom_memo).to eq("From the pending transaction")
    end

    it "is nil when nothing has a custom memo" do
      expect(hcb_code.custom_memo).to be_nil
    end

    it "is used by #memo" do
      hcb_code.ledger_item.update!(custom_memo: "From the ledger item")

      expect(hcb_code.reload.memo).to eq("From the ledger item")
    end
  end
end
