# frozen_string_literal: true

require "rails_helper"

RSpec.describe User::ReceiptBin do
  include_context "receipt pairing"

  def pair(receipt, hcb_code, distance, state = "unreviewed")
    SuggestedPairing.create!(receipt:, hcb_code:, distance:, aasm_state: state)
  end

  it "surfaces the next-best pairing when the best transaction got a receipt elsewhere" do
    best = create_charge
    next_best = create_charge
    receipt = create_receipt
    pair(receipt, best, 5)
    pair(receipt, next_best, 10)
    create_receipt(receiptable: best)

    expect(user.receipt_bin.suggested_receipt_pairings.map(&:hcb_code)).to eq([next_best])
  end

  it "hides receipts the user ignored twice and pairings beyond the cutoff" do
    ignored_twice = create_receipt
    pair(ignored_twice, create_charge, 1, "ignored")
    pair(ignored_twice, create_charge, 2, "ignored")
    pair(ignored_twice, create_charge, 3)
    pair(create_receipt, create_charge, ReceiptService::Suggest::SHOWN_DISTANCE + 1)

    expect(user.receipt_bin.suggested_receipt_pairings).to be_empty
  end
end
