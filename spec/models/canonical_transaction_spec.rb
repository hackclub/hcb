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

  describe "#likely_card_transaction_refund?" do
    let(:card_charge_hcb_code) { instance_double(HcbCode, card_charge?: true) }
    let(:other_hcb_code) { instance_double(HcbCode, card_charge?: false) }

    def build_ct(source_type:, amount_cents:, hcb_code:)
      ct = build(:canonical_transaction, amount_cents:)
      ct.transaction_source_type = source_type
      allow(ct).to receive(:local_hcb_code).and_return(hcb_code)
      ct
    end

    it "is true for a positive Stripe transaction" do
      expect(build_ct(source_type: RawStripeTransaction.name, amount_cents: 100, hcb_code: card_charge_hcb_code)).to be_likely_card_transaction_refund
    end

    it "is true for a dispute payout from Column mapped to a card charge" do
      expect(build_ct(source_type: RawColumnTransaction.name, amount_cents: 100, hcb_code: card_charge_hcb_code)).to be_likely_card_transaction_refund
    end

    it "is false for a Column transaction not mapped to a card charge" do
      expect(build_ct(source_type: RawColumnTransaction.name, amount_cents: 100, hcb_code: other_hcb_code)).not_to be_likely_card_transaction_refund
    end

    it "is false for a negative Column transaction mapped to a card charge" do
      expect(build_ct(source_type: RawColumnTransaction.name, amount_cents: -100, hcb_code: card_charge_hcb_code)).not_to be_likely_card_transaction_refund
    end
  end
end
