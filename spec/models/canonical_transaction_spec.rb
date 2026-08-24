# frozen_string_literal: true

require "rails_helper"

RSpec.describe CanonicalTransaction, type: :model do
  let(:canonical_transaction) { create(:canonical_transaction) }

  it "is valid" do
    expect(canonical_transaction).to be_valid
  end

  describe "friendly_memo" do
    it "does not permit empty string" do
      canonical_transaction.friendly_memo = ""
      expect(canonical_transaction).to_not be_valid

      canonical_transaction.friendly_memo = " "
      expect(canonical_transaction).to_not be_valid

      canonical_transaction.friendly_memo = "Friendly Memo"
      expect(canonical_transaction).to be_valid
    end

    it "does permit nil" do
      canonical_transaction.friendly_memo = nil
      expect(canonical_transaction).to be_valid
    end
  end

  describe "custom_memo" do
    it "treats empty strings as nil" do
      canonical_transaction.custom_memo = ""
      expect(canonical_transaction).to be_valid
      expect(canonical_transaction.custom_memo).to be_nil

      canonical_transaction.custom_memo = " "
      expect(canonical_transaction).to be_valid
      expect(canonical_transaction.custom_memo).to be_nil

      canonical_transaction.custom_memo = "Custom Memo"
      expect(canonical_transaction).to be_valid
    end

    it "removes whitespace from strings" do
      canonical_transaction.custom_memo = " Custom Memo"
      expect(canonical_transaction).to be_valid
      expect(canonical_transaction.custom_memo).to eql("Custom Memo")
    end

    it "does permit nil" do
      canonical_transaction.custom_memo = nil
      expect(canonical_transaction).to be_valid
    end
  end

  describe "#search_memo" do
    context "when the memo is a partial match for the search query" do
      it "still finds the transaction" do
        canonical_transaction = create(:canonical_transaction, memo: "POSTAGE GOSHIPPO.COM")
        expect(CanonicalTransaction.search_memo("go shippo")).to contain_exactly(canonical_transaction)
      end
    end
  end

  describe "hcb_code" do
    it "is reachable from the canonical transaction and is created eagerly" do
      canonical_transaction = create(:canonical_transaction)
      expect { canonical_transaction.local_hcb_code }.to_not change(HcbCode, :count)
      expect(canonical_transaction.local_hcb_code).to be_present
    end
  end

  describe "#assign_ledger_item" do
    it "reuses the local hcb_code's existing ledger item instead of creating a duplicate" do
      hcb_code = create(:hcb_code)
      ledger_item = create(:ledger_item, short_code: hcb_code.short_code)
      hcb_code.update!(ledger_item:)

      # Simulate a second canonical transaction settling onto an hcb_code that
      # already has a ledger item, via a linked_object type not covered by
      # `linked_object_v2` (e.g. a BankFee/Disbursement/Donation leg) - so
      # `calculated_ledger_item` can't find it and would otherwise attempt to
      # create a second `Ledger::Item` with the same (unique) short_code.
      canonical_transaction.update_column(:hcb_code, hcb_code.hcb_code)
      canonical_transaction.reload_local_hcb_code

      expect { canonical_transaction.send(:assign_ledger_item) }.to_not change(Ledger::Item, :count)
      expect(canonical_transaction.reload.ledger_item).to eq(ledger_item)
    end
  end
end
