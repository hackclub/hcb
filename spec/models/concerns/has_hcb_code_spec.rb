# frozen_string_literal: true

require "rails_helper"

RSpec.describe HasHcbCode do
  let(:event) {
    event = create(:event)
    create(:canonical_pending_transaction, amount_cents: 1000, event:, fronted: true)
    event
  }

  # Creating a canonical (pending) transaction recomputes its HCB code from the
  # memo, so group it onto the record's code afterwards.
  def group(transaction, onto:)
    transaction.update_column(:hcb_code, onto.hcb_code)
    transaction
  end

  describe "#canonical_transactions" do
    it "finds the canonical transactions grouped under the record's HCB code" do
      ach_transfer = create(:ach_transfer, event:)
      transaction = group(create(:canonical_transaction), onto: ach_transfer)
      create(:canonical_transaction)

      expect(ach_transfer.canonical_transactions).to contain_exactly(transaction)
    end

    it "works for a model that stores its HCB code in a column" do
      bank_fee = create(:bank_fee, event:)
      transaction = group(create(:canonical_transaction), onto: bank_fee)

      expect(bank_fee.canonical_transactions).to contain_exactly(transaction)
    end
  end

  describe "#pending_expired?" do
    let(:ach_transfer) { create(:ach_transfer, event:) }

    it "is false while the pending transaction is recent" do
      group(create(:canonical_pending_transaction, created_at: 1.day.ago), onto: ach_transfer)

      expect(ach_transfer.pending_expired?).to be(false)
    end

    it "is true once an unsettled pending transaction is older than five days" do
      group(create(:canonical_pending_transaction, created_at: 6.days.ago), onto: ach_transfer)

      expect(ach_transfer.pending_expired?).to be(true)
    end
  end

  describe "#short_code_memo" do
    it "prefixes the HcbCode short code" do
      ach_transfer = create(:ach_transfer, event:)

      expect(ach_transfer.short_code_memo).to eq("HCB-#{ach_transfer.local_hcb_code.short_code}")
      expect(ach_transfer.short_code_memo).to match(/\AHCB-[A-Z0-9]{5}\z/)
    end
  end
end
