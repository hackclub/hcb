# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReceiptService::Suggest do
  include_context "receipt pairing"

  let(:matching) { { extracted_total_amount_cents: 12_34, extracted_date: charged_at } }

  def score(receipt, hcb_code) = described_class.new(receipt:).score(hcb_code)

  describe "#score" do
    it "counts features it can't compare as unknown rather than as mismatches" do
      result = score(create_receipt(**matching), create_charge(merchant: { "name" => "BLUE BOTTLE COFFEE" }))

      expect(result[:features]).to include(amount: 0, date: 0, card_last_four: nil, merchant_zip_code: nil, merchant_name: nil)
      expect(result[:distance]).to eq(25)
    end

    it "compares postal codes as strings, ignoring ZIP+4 and Stripe's placeholder" do
      london = create_charge(merchant: { "name" => "Pret", "postal_code" => "SW1A 1AA" })

      expect(score(create_receipt(**matching, extracted_merchant_zip_code: "sw1a 1aa"), london)[:features][:merchant_zip_code]).to eq(0)
      expect(score(create_receipt(**matching, extracted_merchant_zip_code: "EC1A 1BB"), london)[:features][:merchant_zip_code]).to eq(1)
      expect(score(create_receipt(**matching, extracted_merchant_zip_code: "94103-1234"), create_charge)[:features][:merchant_zip_code]).to eq(0)
      expect(score(create_receipt(**matching, extracted_merchant_zip_code: "94110"), create_charge)[:features][:merchant_zip_code]).to eq(1)
      expect(score(create_receipt(**matching, extracted_merchant_zip_code: "94103"), create_charge(merchant: { "name" => "X", "postal_code" => "00000" }))[:features][:merchant_zip_code]).to be_nil
    end

    it "grades the amount: exact, subtotal, a tip on top, a discount, or a mismatch" do
      receipt = create_receipt(extracted_total_amount_cents: 10_00, extracted_subtotal_amount_cents: 9_00, extracted_date: charged_at)

      expect(score(receipt, create_charge(amount_cents: 10_00))[:features][:amount]).to eq(0)
      expect(score(receipt, create_charge(amount_cents: 9_00))[:features][:amount]).to eq(0.25)
      expect(score(receipt, create_charge(amount_cents: 11_50))[:features][:amount]).to eq(0.7)
      expect(score(receipt, create_charge(amount_cents: 8_50))[:features][:amount]).to eq(0.8)
      expect(score(receipt, create_charge(amount_cents: 20_00))[:features][:amount]).to eq(1)
    end

    it "still counts an identical number when the receipt's currency was read differently" do
      receipt = create_receipt(**matching, extracted_currency: "CAD")

      expect(score(receipt, create_charge)[:features][:amount]).to eq(0.1)
      expect(score(receipt, create_charge(amount_cents: 13_00))[:features][:amount]).to eq(1)
    end

    it "expects the charge on the receipt's date or the day after" do
      charge = create_charge

      expect(score(create_receipt(**matching, extracted_date: charged_at - 1.day), charge)[:features][:date]).to eq(0)
      expect(score(create_receipt(**matching, extracted_date: charged_at + 1.day), charge)[:features][:date]).to eq(0.5)
      expect(score(create_receipt(**matching, extracted_date: charged_at - 10.days), charge)[:features][:date]).to eq(1)
    end

    it "falls back to how soon the receipt was uploaded when it has no date" do
      receipt = create_receipt(extracted_total_amount_cents: 12_34)

      expect(score(receipt, create_charge)[:distance]).to be < score(receipt, create_charge(at: charged_at - 40.days))[:distance]
    end

    it "matches merchant names by similarity and tolerates a missing Stripe name" do
      expect(score(create_receipt(**matching, extracted_merchant_name: "Blue Bottle"), create_charge)[:features][:merchant_name]).to eq(0)
      expect(score(create_receipt(**matching, extracted_merchant_name: "Target"), create_charge)[:features][:merchant_name]).to eq(1)
      expect(score(create_receipt(**matching, extracted_merchant_name: "Target"), create_charge(merchant: { "postal_code" => "94103" }))[:features][:merchant_name]).to be_nil
    end
  end

  describe "#run!" do
    def run(receipt)
      described_class.new(receipt:).run!
      receipt.reload.hcb_code
    end

    it "auto-attaches when exactly one charge fits" do
      hcb_code = create_charge
      create_charge(amount_cents: 50_00, at: charged_at - 20.days)
      receipt = create_receipt(**matching)

      expect(run(receipt)).to eq(hcb_code)
      expect(receipt.suggested_pairings.find_by(hcb_code:)).to be_accepted
    end

    it "picks the right month of a recurring charge by date" do
      create_charge(at: charged_at - 30.days)
      hcb_code = create_charge

      expect(run(create_receipt(**matching))).to eq(hcb_code)
    end

    it "does not auto-attach when another charge of the same amount is close in date" do
      create_charge
      create_charge(at: charged_at - 3.days)
      receipt = create_receipt(**matching)

      expect(run(receipt)).to be_nil
      expect(receipt.suggested_pairings.unreviewed.count).to eq(2)
    end

    it "does not auto-attach when the same merchant was charged again within the hour" do
      create_charge
      create_charge(amount_cents: 40_00, at: charged_at + 20.minutes)

      expect(run(create_receipt(**matching, extracted_merchant_name: "Blue Bottle"))).to be_nil
    end

    it "does not auto-attach an amount that only matches with a tip" do
      create_charge(amount_cents: 14_00)

      expect(run(create_receipt(**matching, extracted_merchant_name: "Blue Bottle"))).to be_nil
    end

    it "auto-attaches without a date only if the amount singles the charge out and the merchant matches" do
      hcb_code = create_charge
      create_charge(amount_cents: 50_00, at: charged_at - 2.days)

      expect(run(create_receipt(extracted_total_amount_cents: 12_34))).to be_nil
      expect(run(create_receipt(extracted_total_amount_cents: 12_34, extracted_merchant_name: "Blue Bottle"))).to eq(hcb_code)
    end

    it "does not auto-attach without a date when another charge is within tipping range" do
      create_charge
      create_charge(amount_cents: 14_00, at: charged_at - 2.days)

      expect(run(create_receipt(extracted_total_amount_cents: 12_34, extracted_merchant_name: "Blue Bottle"))).to be_nil
    end

    it "stores only the closest few pairings under the distance cap" do
      7.times { |i| create_charge(at: charged_at + (i * 2).hours) }
      create_charge(amount_cents: 99_00, merchant: { "name" => "Elsewhere", "postal_code" => "10001" }, at: charged_at + 4.days)
      receipt = create_receipt(**matching)

      described_class.new(receipt:).run!

      expect(receipt.suggested_pairings.count).to eq(described_class::STORED_PAIRINGS)
      expect(receipt.suggested_pairings.pluck(:distance)).to all(be <= described_class::SHOWN_DISTANCE)
    end

    it "keeps ignored pairings ignored when re-scoring" do
      create_charge
      create_charge
      receipt = create_receipt(**matching)
      described_class.new(receipt:).run!
      ignored = receipt.suggested_pairings.first
      ignored.mark_ignored!

      described_class.new(receipt: receipt.reload).run!

      expect(ignored.reload).to be_ignored
    end

    it "skips pairing for receipts uploaded onto a transaction" do
      hcb_code = create_charge
      create_charge
      receipt = create_receipt(receiptable: hcb_code, **matching)

      described_class.new(receipt:).run!

      expect(receipt.suggested_pairings).to be_empty
    end
  end
end
