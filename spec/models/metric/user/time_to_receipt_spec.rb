# frozen_string_literal: true

require "rails_helper"

RSpec.describe Metric::User::TimeToReceipt do
  def attach_receipt_to(receiptable, user:, created_at:)
    receipt = Receipt.new(receiptable:, user:, upload_method: :api, created_at:)
    receipt.file.attach(
      io: StringIO.new(File.binread(Rails.root.join("spec/fixtures/files/receipt.png"))),
      filename: "receipt.png", content_type: "image/png"
    )
    receipt.save!
    receipt
  end

  # Receipts are moving onto ledger items (#14106); a receipt on either side
  # counts, measured from the HCB code's creation.
  it "averages the time from the HCB code's creation to each receipt, wherever it is attached" do
    user = create(:user)
    created_at = Time.zone.local(Metric.year, 6, 1, 12)
    hcb_code = create(:canonical_pending_transaction).local_hcb_code.reload
    hcb_code.update_column(:created_at, created_at)

    attach_receipt_to(hcb_code.ledger_item, user:, created_at: created_at + 1.hour)
    attach_receipt_to(hcb_code, user:, created_at: created_at + 3.hours)

    expect(described_class.new(subject: user).calculate).to eq(2.hours.to_i)
  end

  it "ignores other users' receipts" do
    user = create(:user)
    created_at = Time.zone.local(Metric.year, 6, 1, 12)
    hcb_code = create(:canonical_pending_transaction).local_hcb_code.reload
    hcb_code.update_column(:created_at, created_at)

    attach_receipt_to(hcb_code.ledger_item, user: create(:user), created_at: created_at + 1.hour)

    expect(described_class.new(subject: user).calculate).to be_nil
  end
end
