# frozen_string_literal: true

require "rails_helper"

RSpec.describe User::RescoreReceiptPairingsJob do
  include_context "receipt pairing"

  before { travel_to(charged_at + 1.day) }

  it "pairs a receipt uploaded before its charge existed" do
    receipt = create_receipt(extracted_total_amount_cents: 12_34, extracted_date: charged_at)
    expect(receipt.suggested_pairings).to be_empty

    hcb_code = create_charge
    described_class.perform_now(user_id: user.id)

    expect(receipt.reload.receiptable).to eq(hcb_code)
  end

  it "leaves receipts that are not in the receipt bin alone" do
    hcb_code = create_charge
    receipt = create_receipt(receiptable: hcb_code, extracted_total_amount_cents: 12_34, extracted_date: charged_at)
    create_charge

    described_class.perform_now(user_id: user.id)

    expect(receipt.suggested_pairings).to be_empty
  end
end
