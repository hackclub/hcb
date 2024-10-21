# frozen_string_literal: true

require "rails_helper"

HCBCode = TransactionGroupingEngine::Calculate::HcbCode


describe HcbCodeService::CanDispute do

  context "when it's an invalid transaction" do
    let(:hcb_code) { build(:hcb_code) }

    it "returns false" do
      result, error_reason = described_class.new(hcb_code:).run

      expect(result).to eq(false)
      expect(error_reason).to eq("This is not a valid transaction")
    end
  end

  context "when it's valid transaction but not a stripe transaction" do
    let(:hcb_code) { build(:hcb_code) }
    let!(:ct) { create(:canonical_transaction).update(hcb_code: hcb_code.hcb_code) }

    it "returns false" do
      result, error_reason = described_class.new(hcb_code:).run

      expect(result).to eq(false)
      expect(error_reason).to eq("Can not dispute this type of transaction")
    end
  end


  context "when stripe transaction is older than 90 days" do
    let(:hcb_code) { build(:hcb_code, code_type: ::HCBCode::STRIPE_CARD_CODE) }
    let!(:ct) { create(:canonical_transaction, date: Date.today - 91.days).update(hcb_code: hcb_code.hcb_code) }

    it "returns false" do
      result, error_reason = described_class.new(hcb_code:).run

      expect(result).to eq(false)
      expect(error_reason).to eq("Card transactions older than 90 days can not be disputed.")
    end
  end

  context "when it's a bank transaction older than 90 days" do
    let(:ct) { create(:canonical_transaction, date: Date.today - 91.days, amount_cents: -1) }

    it "returns false" do
      hcb_code = ct.local_hcb_code

      result, error_reason = described_class.new(hcb_code:).run

      expect(result).to eq(false)
      expect(error_reason).to eq("Bank account transactions older than 90 days can not be disputed.")
    end
  end

  context "when stripe transaction is newer than 90 days" do
    let(:hcb_code) { build(:hcb_code, code_type: ::HCBCode::STRIPE_CARD_CODE) }
    let!(:ct) { create(:canonical_transaction, date: Date.today - 90.days).update(hcb_code: hcb_code.hcb_code) }

    it "returns true" do
      result, = described_class.new(hcb_code:).run

      expect(result).to eq(true)
    end
  end

  context "when transaction is a donation" do
    let(:hcb_code) { build(:hcb_code, code_type: ::HCBCode::DONATION_CODE) }
    let!(:ct) { create(:canonical_transaction).update(hcb_code: hcb_code.hcb_code) }


    it "returns true" do
      result, = described_class.new(hcb_code:).run

      expect(result).to eq(true)
    end
  end

  context "when transaction is a bank transaction newer than 90 days" do
    let(:ct) { create(:canonical_transaction, date: Date.today - 90.days, amount_cents: -1) }

    it "returns true" do
      hcb_code = ct.local_hcb_code
      result, = described_class.new(hcb_code:).run

      expect(result).to eq(true)
    end
  end
end
